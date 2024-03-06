/*! \file jclklib_import.hpp
    \brief C API import.

    (C) Copyright Intel Corporation 2023. All rights reserved. Intel Confidential.
    Author: Christopher Hall <christopher.s.hall@intel.com>
*/

#include <cstdint>

#ifndef JCLKLIB_IMPORT_HPP
#define JCLKLIB_IMPORT_HPP

#include <common/util.hpp>

namespace JClkLibCommon
{
	typedef enum : std::uint8_t
		{ gmOffsetValue,
		  valueLast } valueType;
#define MAX_VALUE_COUNT 12
		
	class jcl_value
	{
	private:
		struct value_t {
			std::uint32_t upper;
			std::uint32_t lower;
			value_t();
			value_t(uint32_t limit);
			bool equal(const value_t &v);
			bool operator== (const value_t &value) { return this->equal(value); }
			bool operator!= (const value_t &value) { return !this->equal(value); }
			void zero() { upper = 0; lower = 0; }
		};
		value_t value[valueLast];
		value_t reserved[MAX_VALUE_COUNT-sizeof(value)/sizeof(value[0])];
	public:
		std::uint8_t *parse(std::uint8_t *buf, std::size_t &length);
		std::uint8_t *write(std::uint8_t *buf, std::size_t &length);
		bool equal( const jcl_value &c);
		bool operator== (const jcl_value &value) { return this->equal(value); }
		bool operator!= (const jcl_value &value) { return !this->equal(value); }
	};

	typedef enum : std::uint8_t
		{ peerPresentEvent, gmPresentEvent, gmOffsetEvent, servoLockedEvent,
		  eventLast } eventType;
#define BITS_PER_BYTE (8)
#define MAX_EVENT_COUNT (128)

	class jcl_event
	{
	private:
		std::uint32_t event_mask[eventLast/(sizeof(std::uint32_t)*BITS_PER_BYTE)+1];
		std::uint32_t reserved[MAX_EVENT_COUNT/
				       sizeof(event_mask[0]*BITS_PER_BYTE)
				       -sizeof(event_mask)/sizeof(std::uint32_t)];
	public:
		std::uint8_t *parse(std::uint8_t *buf, std::size_t &length);
		std::uint8_t *write(std::uint8_t *buf, std::size_t &length);
		void zero();
		bool equal( const jcl_event &c);
		bool operator== (const jcl_event &event) { return this->equal(event); }
		bool operator!= (const jcl_event &event) { return !this->equal(event); }
	};


	class jcl_eventcount
	{
		std::uint32_t count[eventLast];
		std::uint32_t reserved[MAX_EVENT_COUNT-eventLast];
	public:
		std::uint8_t *parse(std::uint8_t *buf, std::size_t &length);
		std::uint8_t *write(std::uint8_t *buf, std::size_t &length);
		void zero();
		bool equal(const jcl_eventcount &ec);
		bool operator== (const jcl_eventcount &ec) { return this->equal(ec); }
		bool operator!= (const jcl_eventcount &ec) { return !this->equal(ec); }
	};

	class jcl_subscription
	{
	private:
		jcl_event        event;
		jcl_value        value;
	public:
		std::uint8_t *parse(std::uint8_t *buf, std::size_t &length);
		std::uint8_t *write(std::uint8_t *buf, std::size_t &length);

		DECLARE_ACCESSOR(event);
		DECLARE_ACCESSOR(value);
	};
}

#endif/*JCLKLIB_IMPORT_HPP*/