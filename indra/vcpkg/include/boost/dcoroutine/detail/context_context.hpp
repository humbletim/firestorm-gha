//  Copyright (c) 2006, Giovanni P. Deretta
//  Adapted 2012-11-02 from context_posix.hpp by Nathaniel R. Goodspeed
//
//  This code may be used under either of the following two licences:
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is 
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
//  THE SOFTWARE. OF SUCH DAMAGE.
//
//  Or:
//
//  Distributed under the Boost Software License, Version 1.0.
//  (See accompanying file LICENSE_1_0.txt or copy at
//  http://www.boost.org/LICENSE_1_0.txt)

#ifndef BOOST_COROUTINE_CONTEXT_CONTEXT_HPP
#define BOOST_COROUTINE_CONTEXT_CONTEXT_HPP

#include <boost/config.hpp>
#include <boost/assert.hpp>
#include <boost/context/fcontext.hpp>
#include <boost/coroutine/stack_traits.hpp>
#include <boost/coroutine/stack_allocator.hpp>
#include <boost/noncopyable.hpp>
#include <boost/dcoroutine/exception.hpp>
#include <boost/dcoroutine/detail/swap_context.hpp>
#include <boost/function.hpp>
#include <boost/shared_ptr.hpp>

#define BOOST_CORO_IMPL "Boost.Context implementation"

/*
 * Boost.Context based context implementation. Should be available with every
 * Boost >= 1.52.
 * NOTE: Specifically in Boost 1.52, Boost.Context has a bug when built for
 * 32-bit Mac. We hope the bug fix will make it into the official Boost 1.53
 * release. Meanwhile, we've patched into the Linden Boost source repository.
 */

namespace boost { namespace dcoroutines { namespace detail {
  namespace context {
    /**
     * stack_holder_with<StackAllocator>(StackAllocator_instance, size) is
     * an RAII class to acquire and release a stack suitable for use with
     * Boost.Context. stack_holder_with is for when you want to explicitly
     * instantiate your StackAllocator, sharing a single instance between
     * multiple stack_holder_with instances.
     */
    template <class StackAllocator=boost::coroutines::stack_allocator>
    class stack_holder_with: public boost::noncopyable // RAII class
    {
    public:
        // permit consumer to call StackAllocator static methods
        typedef StackAllocator allocator;

        stack_holder_with(allocator& allocref,
                          std::size_t size=coroutines::stack_traits::default_size()):
            mAllocRef(allocref)
        {
            mAllocRef.allocate(mStack, size);
        }
        
        ~stack_holder_with()
        {
            mAllocRef.deallocate(mStack);
        }

        // suitable for calling make_fcontext()
        void* get_stack() const { return mStack.sp; }
        std::size_t get_size() const { return mStack.size; }

        // permit consumer to query bound StackAllocator
        allocator& get_allocator() { return mAllocRef; }
        const allocator& get_allocator() const { return mAllocRef; }

    protected:
        allocator& mAllocRef;
        boost::coroutines::stack_context mStack;
    };

    /**
     * stack_allocator_holder<StackAllocator> is an implementation detail
     * for stack_holder<StackAllocator>. We need a way for a subclass of
     * stack_holder_with to instantiate StackAllocator before running
     * stack_holder_with's constructor. We can do that with an additional
     * base class.
     */
    template <class StackAllocator>
    class stack_allocator_holder
    {
    protected:
        StackAllocator mAllocator;
    };

    /**
     * stack_holder<StackAllocator>() is an RAII class to acquire and
     * release a stack suitable for use with Boost.Context. stack_holder is
     * for when you're okay with a distinct instance of StackAllocator for
     * each different stack_holder instance -- notably when your
     * StackAllocator class is stateless, or when it's not important to
     * share its state between the different stacks you want to allocate
     * with it.
     */
    template <class StackAllocator=boost::coroutines::stack_allocator>
    struct stack_holder: public stack_allocator_holder<StackAllocator>,
                         public stack_holder_with<StackAllocator>
    {
        typedef stack_allocator_holder<StackAllocator> super_holder;
        typedef stack_holder_with<StackAllocator> super_with;

        // publish base-class typedef
        typedef typename super_with::allocator allocator;

        // The point of having stack_allocator_holder be our first base
        // class is so that its mAllocator data member is fully constructed
        // before we get around to constructing our stack_holder_with base
        // class. That lets us pass mAllocator into the second base class
        // constructor.
        stack_holder(std::size_t size=coroutines::stack_traits::default_size()):
            super_with(super_holder::mAllocator, size)
        {}
    };

    // Helper for BOOST_CONTEXT_PRESERVE_FPU(). If the user doesn't use the
    // macro, this provides the default value. We use a compile-time
    // mechanism because Boost.Context requires that every call to
    // jump_fcontext() in a given process must use the same value.
    template <typename T>
    struct boost_context_preserve_fpu
    {
        static inline
        bool value() { return true; }
    };

    // Use BOOST_CONTEXT_PRESERVE_FPU(true) or (false) to set the desired
    // behavior for fcontext_holder::jump_from() throughout this program.
#define BOOST_CONTEXT_PRESERVE_FPU(BOOL)        \
    template <>                                 \
    struct boost_context_preserve_fpu<void>     \
    {                                           \
        static inline                           \
        bool value() { return BOOL; }           \
    };

    /**
     * fcontext_holder<StackAllocator> allocates a stack of specified size
     * AND prepares it using make_fcontext(). For this you must pass not
     * only a size but also the target function pointer.
     */
    template <class StackAllocator=boost::coroutines::stack_allocator>
    class fcontext_holder: public stack_holder<StackAllocator>
    {
        typedef stack_holder<StackAllocator> super;

    public:
        fcontext_holder(void (*fn)(intptr_t),
                        std::size_t size=coroutines::stack_traits::default_size()):
            super(size)
        {
            // Our stack_holder base class already has a stack for us to
            // use. Pass inherited mStack members to make_fcontext().
            mContext = boost::context::make_fcontext(super::mStack.sp, super::mStack.size, fn);
        }

        // This is the fcontext_t you would pass to jump_fcontext()
        boost::context::fcontext_t get_fcontext() const { return mContext; }

        // or you can use this convenience method to jump to this fcontext
        inline
        intptr_t jump_from(boost::context::fcontext_t* ofc, intptr_t p=NULL)
        {
            return boost::context::jump_fcontext(ofc, mContext, p,
                                                 boost_context_preserve_fpu<void>::value());
        }

    private:
        // Since make_fcontext() allocates its fcontext_t on mStack.sp, we
        // don't need to do anything special to free mContext; it goes away
        // when ~stack_holder_with() deallocates mStack.
        boost::context::fcontext_t mContext;
    };

    /*
     * Boost.Context implementation for the context_impl_base class.
     * @note context_impl is not required to be consistent
     * If not initialized it can only be swapped out, not in 
     * (at that point it will be initialized).
     *
     */
    class context_context_impl_base {
    public:
        context_context_impl_base():
            // fcontext_t can be, and in fact MUST be, initialized to 0
            m_ctx(0)
        {}
        virtual ~context_context_impl_base() {}

    private:
        /*
         * Free function. Saves the current context in @p from
         * and restores the context in @p to.
         */     
        friend 
        void 
        swap_context(context_context_impl_base& from, 
                     const context_context_impl_base& to,
                     default_hint) {
            boost::context::jump_fcontext(&from.m_ctx, to.m_ctx, to.get_arg(),
                                          boost_context_preserve_fpu<void>::value());
        }

        // delegate to subclass the problem of supplying an appropriate
        // pointer to pass to jump_fcontext()
        virtual intptr_t get_arg() const { return 0; }

    protected:
        // m_ctx is what we pass to jump_fcontext(). It's usually set by our
        // subclass using make_fcontext(). However, when we first jump from a
        // thread's "main" context, we can leave it initialized to 0;
        // jump_fcontext() will set it appropriately.
        boost::context::fcontext_t m_ctx;
    };

    /**
     * This trampoline() function simply calls the callable passed as its
     * first argument. trampoline() is a classic-C function with the signature
     * required by boost::context::make_fcontext(). Because we must be able to
     * invoke an arbitrary C++ callable, we store that callable and pass its
     * pointer to this function, which can invoke it using the full
     * capabilities of C++.
     */
    template <typename Functor>
    void trampoline(intptr_t argptr)
    {
        // cast argptr to Functor*, then call it
        (*(Functor*)(argptr))();
    }

    class context_context_impl :
        public context_context_impl_base,
        private boost::noncopyable
    {
        // use stack_holder's default StackAllocator, which constructs a guard
        // page to at least produce a machine check on stack overflow instead
        // of silently overwriting other memory
        typedef stack_holder<> stack_holder_type;
    public:
        typedef context_context_impl_base context_impl_base;
  
        /**
         * Create a context that on restore invokes Functor on
         * a new stack. The stack size can be optionally specified.
         *
         * @note It makes me nervous to capture a pointer to the Functor&
         * parameter, since that relies on the Functor instance persisting
         * between this constructor and our base-class swap_context() call.
         * However, Deretta's context_posix.hpp and context_windows.hpp use
         * the same tactic. I did try to store Functor in a boost::function
         * object, but that failed to compile: the Functor actually passed by
         * other layers of this library is noncopyable.
         */
        template<typename Functor>
        explicit
        context_context_impl(Functor& cb, std::ptrdiff_t stack_size) :
            // if caller passes -1, use allocator's default size,
            // else use explicit size
            m_stack(stack_size == -1? coroutines::stack_traits::default_size()
                                    : stack_size),
            // cast Functor ptr to ptr type needed for jump_fcontext()
            m_arg((intptr_t)(&cb))
        {
            // Here we set base-class field
            m_ctx = boost::context::make_fcontext(m_stack.get_stack(),
                                                  m_stack.get_size(),
                                                  &trampoline<Functor>);
        }

        // override base-class get_arg() to return pointer to trampoline
        virtual intptr_t get_arg() const
        {
            // pick up prepared arg
            intptr_t arg = m_arg;
            // but after the first time, reset to NULL -- this is why m_arg is mutable
            m_arg = 0;
            return arg;
        }

    private:
        stack_holder_type m_stack;
        mutable intptr_t m_arg;
    };

    typedef context_context_impl context_impl;
  }
} } }

#endif
