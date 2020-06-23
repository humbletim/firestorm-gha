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

#ifndef BOOST_COROUTINE_COROUTINE_HPP_20060512
#define BOOST_COROUTINE_COROUTINE_HPP_20060512
// On Linux systems, use native swapcontext() et al. rather than
// Boost.Coroutine homebrew assembler
#define BOOST_COROUTINE_NO_ASM
// default_context_impl.hpp must be first for weird Apple bug
#include <boost/dcoroutine/detail/default_context_impl.hpp>
#include <cstddef>
#include <boost/preprocessor/repetition.hpp>
#include <boost/tuple/tuple.hpp>
#include <boost/utility/enable_if.hpp>
#include <boost/mpl/vector.hpp>
#include <boost/type_traits.hpp>
#include <boost/call_traits.hpp>
#include <boost/dcoroutine/detail/arg_max.hpp>
#include <boost/dcoroutine/detail/coroutine_impl.hpp>
#include <boost/dcoroutine/detail/is_callable.hpp>
#include <boost/dcoroutine/detail/argument_packer.hpp>
#include <boost/dcoroutine/detail/argument_unpacker.hpp>
#include <boost/dcoroutine/detail/signature.hpp>
#include <boost/dcoroutine/detail/index.hpp>
#include <boost/dcoroutine/detail/coroutine_traits.hpp>
#include <boost/dcoroutine/detail/coroutine_accessor.hpp>
#include <boost/dcoroutine/move.hpp>
#include <boost/dcoroutine/detail/fix_result.hpp>
#include <boost/dcoroutine/detail/self.hpp>

namespace boost { namespace dcoroutines {
  namespace detail {
    template<typename T>
    struct optional_result_type : 
      boost::mpl::if_<boost::is_same<T, void>,
		      void,
		      boost::optional<T> > { };

    template<typename T>
    BOOST_DEDUCED_TYPENAME
    boost::enable_if<boost::is_same<T, void> >::type
    optional_result() {}

    template<typename T>
    BOOST_DEDUCED_TYPENAME
    boost::disable_if<boost::is_same<T, void>,
		      BOOST_DEDUCED_TYPENAME
		      optional_result_type<T>::type
		      >::type
    optional_result() {
      return BOOST_DEDUCED_TYPENAME
	optional_result_type<T>::type();
    }
  }

  template<typename Signature, typename Context>
  class coroutine;

  template<typename T>
  struct is_coroutine : boost::mpl::false_{};
  
  template<typename Sig, typename Con>
  struct is_coroutine<coroutine<Sig, Con> > : boost::mpl::true_{};

  template<typename Signature, 
	   typename ContextImpl = detail::default_context_impl>
  class coroutine : public movable<coroutine<Signature, ContextImpl> > {
  public:
    typedef coroutine<Signature, ContextImpl> type;
    typedef ContextImpl context_impl;
    typedef Signature signature_type;
    friend struct detail::coroutine_accessor;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::result_type result_type;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::result_slot_type result_slot_type;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::yield_result_type yield_result_type;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::result_slot_traits result_slot_traits;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::arg_slot_type arg_slot_type;

    typedef BOOST_DEDUCED_TYPENAME 
    detail::coroutine_traits<signature_type>
    ::arg_slot_traits arg_slot_traits;
        
    typedef detail::coroutine_impl<type, context_impl> impl_type;
    typedef BOOST_DEDUCED_TYPENAME  impl_type::pointer impl_ptr;  
   
    typedef detail::coroutine_self<type> self;
    coroutine() : m_pimpl(0) {}

    template<typename Functor>
    coroutine (Functor f, 
	       std::ptrdiff_t stack_size = detail::default_stack_size,
	       BOOST_DEDUCED_TYPENAME boost::enable_if<
	       boost::mpl::and_<
	       detail::is_callable<Functor>, 
	       boost::mpl::not_<is_coroutine<Functor> >
	       > >
	       ::type * = 0
	       ) :
      m_pimpl(impl_type::create(f, stack_size)) {}
 
    coroutine(move_from<coroutine> src) 
      : m_pimpl(src->m_pimpl) {
      src->m_pimpl = 0;
    }

    coroutine& operator=(move_from<coroutine> src) {
      coroutine(src).swap(*this);
      return *this;
    }

    coroutine& swap(coroutine& rhs) {
      std::swap(m_pimpl, rhs.m_pimpl);
      return *this;
    }

    friend
    void swap(coroutine& lhs, coroutine& rhs) {
      lhs.swap(rhs);
    }

#   define BOOST_COROUTINE_generate_argument_n_type(z, n, traits_type) \
    typedef BOOST_DEDUCED_TYPENAME traits_type ::template at<n>::type  \
    BOOST_PP_CAT(BOOST_PP_CAT(arg, n), _type);                         \
    /**/

    BOOST_PP_REPEAT(BOOST_COROUTINE_ARG_MAX,
		    BOOST_COROUTINE_generate_argument_n_type,
		    arg_slot_traits);

    static const int arity = arg_slot_traits::length;

    struct yield_traits {
      BOOST_PP_REPEAT(BOOST_COROUTINE_ARG_MAX,
		      BOOST_COROUTINE_generate_argument_n_type,
		      result_slot_traits);
      static const int arity = result_slot_traits::length;
    };

#   undef BOOST_COROUTINE_generate_argument_n_type
   
#   define BOOST_COROUTINE_param_with_default(z, n, type_prefix)    \
    BOOST_DEDUCED_TYPENAME call_traits                              \
    <BOOST_PP_CAT(BOOST_PP_CAT(type_prefix, n), _type)>::param_type \
    BOOST_PP_CAT(arg, n) =                                          \
    BOOST_PP_CAT(BOOST_PP_CAT(type_prefix, n), _type)()             \
    /**/

    result_type operator()
      (BOOST_PP_ENUM
       (BOOST_COROUTINE_ARG_MAX,
	BOOST_COROUTINE_param_with_default,
	arg)) {
      return call_impl
	(arg_slot_type(BOOST_PP_ENUM_PARAMS
	  (BOOST_COROUTINE_ARG_MAX, 
	   arg)));
    }

    BOOST_DEDUCED_TYPENAME
    detail::optional_result_type<result_type>::type 
    operator()
      (const std::nothrow_t&
       BOOST_PP_ENUM_TRAILING
       (BOOST_COROUTINE_ARG_MAX,
	BOOST_COROUTINE_param_with_default,
	arg)) {
      return call_impl_nothrow
	(arg_slot_type(BOOST_PP_ENUM_PARAMS
	  (BOOST_COROUTINE_ARG_MAX, 
	   arg)));
    }

#   undef BOOST_COROUTINE_param_typedef
#   undef BOOST_COROUTINE_param_with_default

    typedef void(coroutine::*bool_type)();
    operator bool_type() const {
      return good()? &coroutine::bool_type_f: 0;
    }

    bool operator==(const coroutine& rhs) {
      return m_pimpl == rhs.m_pimpl;
    }

    void exit() {
      BOOST_ASSERT(m_pimpl);
      m_pimpl->exit();
    }

    bool waiting() const {
      BOOST_ASSERT(m_pimpl);
      return m_pimpl->waiting();
    }

    bool pending() const {
      BOOST_ASSERT(m_pimpl);
      return m_pimpl->pending();
    }

    bool exited() const {
      BOOST_ASSERT(m_pimpl);
      return m_pimpl->exited();
    }

    bool empty() const {
      return m_pimpl == 0;
    }
  protected:

    // The second parameter is used to avoid calling this constructor
    // by mistake from other member funcitons (specifically operator=).
    coroutine(impl_type * pimpl, detail::init_from_impl_tag) :
      m_pimpl(pimpl) {}

    void bool_type_f() {}

    bool good() const  {
      return !empty() && !exited() && !waiting();
    }

    result_type call_impl(arg_slot_type args) {
      BOOST_ASSERT(m_pimpl);
      m_pimpl->bind_args(&args);
      BOOST_DEDUCED_TYPENAME impl_type::local_result_slot_ptr ptr(m_pimpl);
      m_pimpl->invoke();

      return detail::fix_result<result_slot_traits>(*m_pimpl->result());
    }

    BOOST_DEDUCED_TYPENAME
    detail::optional_result_type<result_type>::type 
    call_impl_nothrow(arg_slot_type args) {
      BOOST_ASSERT(m_pimpl);
      m_pimpl->bind_args(&args);
      BOOST_DEDUCED_TYPENAME impl_type::local_result_slot_ptr ptr(m_pimpl);
      if(!m_pimpl->wake_up())
	return detail::optional_result<result_type>();

      return detail::fix_result<result_slot_traits>(*m_pimpl->result());
    }

    impl_ptr m_pimpl;

    void acquire() {
      m_pimpl->acquire();
    }

    void release() {
      m_pimpl->release();
    }

    std::size_t
    count() const {
      return m_pimpl->count();
    }

    impl_ptr get_impl() {
      return m_pimpl;
    }
  };
} }
#endif
