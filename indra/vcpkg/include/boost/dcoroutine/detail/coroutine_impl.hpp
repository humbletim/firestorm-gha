//  Copyright (c) 2006, Giovanni P. Deretta
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

#ifndef BOOST_COROUTINE_COROUTINE_IMPL_HPP_20060601
#define BOOST_COROUTINE_COROUTINE_IMPL_HPP_20060601
#if defined(_MSC_VER)
#pragma warning (push)
#pragma warning (disable: 4355) //this used in base member initializer
#endif 

#include <cstddef>
#include <boost/optional.hpp>
#include <boost/dcoroutine/detail/argument_unpacker.hpp>
#include <boost/dcoroutine/detail/coroutine_accessor.hpp>
#include <boost/dcoroutine/detail/context_base.hpp>

namespace boost { namespace dcoroutines { namespace detail {
	
  // This class augment the contest_base class with
  // the coroutine signature type.
  // This is mostly just a place to put
  // typesafe argument and result type pointers.
  template<typename CoroutineType, typename ContextImpl>
  class coroutine_impl:
    public context_base<ContextImpl>
  {
  public:
    template<typename DerivedType, typename ResultType>
    friend class add_result;

    typedef ContextImpl context_impl;
    typedef CoroutineType coroutine_type;
    typedef coroutine_impl<coroutine_type, context_impl> type;
    typedef context_base<context_impl> context_base_type;
    typedef typename coroutine_type::arg_slot_type arg_slot_type;
    typedef typename coroutine_type::result_type result_type;
    typedef typename coroutine_type::result_slot_type result_slot_type;

    typedef boost::intrusive_ptr<type> pointer;
  
    template<typename DerivedType>
	coroutine_impl(DerivedType * this_, std::ptrdiff_t stack_size) :
      context_base_type(*this_, stack_size),
	m_arg(0),
	m_result(0){}
                
    // have to match throw() guarantee of ~context_base()
    ~coroutine_impl() throw() {}

    arg_slot_type * args() {
      BOOST_ASSERT(m_arg);
      return m_arg;
    };
    
    result_slot_type * result() {
      BOOST_ASSERT(m_result);
      BOOST_ASSERT(*m_result);
      return *this->m_result;
    } 

    template<typename Functor>
	static inline	
	pointer create(Functor, std::ptrdiff_t = default_stack_size);

    void bind_args(arg_slot_type* arg) {
      m_arg = arg;
    }
    
    void bind_result(result_slot_type* res) {
      // This used to be unconditional. But m_result isn't always valid.
      if (m_result) {
        *m_result = res;
      }
    }

    // Another level of indirecition is needed to handle
    // yield_to correctly.
    void bind_result_pointer(result_slot_type** resp) {
      m_result = resp;
    }

    result_slot_type** result_pointer() {
      return m_result;
    }

    /// This helper class packages data/logic originally found inline in
    /// coroutine::call_impl() and call_impl_nothrow(), also
    /// coroutine_impl::run().
    class local_result_slot_ptr
    {
    public:
        local_result_slot_ptr(pointer pimpl):
            m_pimpl(pimpl),
            m_ptr(NULL)
        {
            m_pimpl->bind_result_pointer(&m_ptr);
        }
        ~local_result_slot_ptr()
        {
            // In the original use case, a coroutine could only be resumed by
            // calling coroutine::operator() again, which would rebind the
            // result pointer to a new valid value. But with the introduction
            // of futures, it's possible to suspend a coroutine by waiting on
            // a future object -- thus destroying the local result_slot_type*
            // -- then resume that coroutine by calling the future's callback,
            // bypassing coroutine::operator(). This used to leave an old,
            // invalid result pointer in effect. Subsequent coroutine exit
            // wrote through that pointer, munging a word of stack. Now we
            // make a point of setting the bound result pointer NULL when the
            // result_slot_type* to which it pointed vanishes, so that any
            // attempt to dereference it will at least self-identify --
            // instead of producing arbitrary undefined behavior.
            m_pimpl->bind_result_pointer(NULL);
        }

    private:
        pointer m_pimpl;
        result_slot_type* m_ptr;
    };

    // This function must be called only for void
    // coroutines. It wakes up the coroutine.
    // Entering the wait state does not cause this
    // method to throw.
    void run() {
      arg_slot_type void_args;
      
      // This dummy binding is required because
      // do_call expect args() and result()
      // to return a non NULL result.
      bind_args(&void_args);
      local_result_slot_pointer(this);
      this->wake_up();
    }
  protected:
    boost::optional<result_slot_type>  m_result_last;

  private:
    arg_slot_type * m_arg;
    result_slot_type ** m_result;

  };

  // This type augment coroutine_impl type with the type of the stored 
  // functor. The type of this object is erased right after construction
  // when it is assigned to a pointer to coroutine_impl. A deleter is
  // passed down to make it sure that the correct derived type is deleted.
  template<typename FunctorType, typename CoroutineType, typename ContextImpl>
  class coroutine_impl_wrapper :
    public coroutine_impl<CoroutineType, ContextImpl> {
  public:
    typedef coroutine_impl_wrapper<FunctorType, CoroutineType, ContextImpl> 
    type;
    typedef CoroutineType coroutine_type;
    typedef typename CoroutineType::result_type result_type;
    typedef coroutine_impl<CoroutineType, ContextImpl> super_type;

    typedef FunctorType functor_type;
	coroutine_impl_wrapper(functor_type f, std::ptrdiff_t stack_size) :

		super_type(this, stack_size),
      m_fun(f){}

    // have to keep throw() promise made by base-class destructor
    ~coroutine_impl_wrapper() throw() {}

    void operator()() {
      typedef typename super_type::context_exit_status
	context_exit_status;
      context_exit_status status = super_type::ctx_exited_return;
      std::type_info const* tinfo = 0;
      try {
	this->check_exit_state();
	do_call<result_type>();
      } catch (const exit_exception&) {
	status = super_type::ctx_exited_exit;
      } catch (std::exception const& e) {
	status = super_type::ctx_exited_abnormally;
	tinfo = &typeid(e);
      } catch (...) {
	status = super_type::ctx_exited_abnormally;
      }
      this->do_return(status, tinfo);	  
    }
  public:    

    //GCC workaround as per enable_if docs 
    template <int> struct dummy { dummy(int) {} };
    /*
     * Implementation for operator()
     * This is for void result types.
     * Can throw if m_fun throws. At least it can throw exit_exception.
     */
    template<typename ResultType>
    typename boost::enable_if<boost::is_void<ResultType> >::type
    do_call(dummy<0> = 0) {
      BOOST_ASSERT(this->count() > 0);
      typedef BOOST_DEDUCED_TYPENAME
	coroutine_type::self self_type;
      boost::optional<self_type> self (coroutine_accessor::in_place(this));
      detail::unpack_ex
	(m_fun, 
	 *self, 
	 *this->args(), 
	 detail::trait_tag<typename coroutine_type::arg_slot_traits>());

      typedef BOOST_DEDUCED_TYPENAME coroutine_type::result_slot_type 
	result_slot_type;

      // In this particulare case result_slot_type is guaranteed to be
      // default constructible.
      this->m_result_last = result_slot_type();
      this->bind_result(&*this->m_result_last);
    }

    // Same as above, but for non void result types.
    template<typename ResultType>
    typename boost::disable_if<boost::is_void<ResultType> >::type
    do_call(dummy<1> = 1) {
      BOOST_ASSERT(this->count() > 0);
      typedef BOOST_DEDUCED_TYPENAME
      coroutine_type::self self_type;

      boost::optional<self_type> self (coroutine_accessor::in_place(this));

      typedef BOOST_DEDUCED_TYPENAME coroutine_type::arg_slot_traits traits;
      typedef BOOST_DEDUCED_TYPENAME coroutine_type::result_slot_type 
	result_slot_type;
	  
      this->m_result_last = boost::in_place(result_slot_type(detail::unpack_ex
			   (m_fun, 
			    *self, 
			    *this->args(), 
			    detail::trait_tag<traits>())));      
      
      this->bind_result(&*this->m_result_last);
    }
  
    FunctorType m_fun;
  };

  template<typename CoroutineType, typename ContextImpl>
  template<typename Functor>
  inline
  typename 
  coroutine_impl<CoroutineType, ContextImpl>::pointer
  coroutine_impl<CoroutineType, ContextImpl>::
  create(Functor f, std::ptrdiff_t stack_size) {
    return new coroutine_impl_wrapper<Functor, CoroutineType, ContextImpl>
      (f, stack_size);      
  }

} } }
#if defined(_MSC_VER)
#pragma warning(pop)
#endif
#endif
