// Copyright 2026 Open Source Robotics Foundation, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <gtest/gtest.h>

#include <array>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "fastcdr/Cdr.h"
#include "fastcdr/FastBuffer.h"
#include "rosidl_buffer/buffer.hpp"
#include "rmw/topic_endpoint_info.h"
#include "rosidl_typesupport_fastrtps_cpp/buffer_serialization.hpp"

namespace
{

class TestBufferImpl : public rosidl::BufferImplBase<uint8_t>
{
public:
  explicit TestBufferImpl(std::vector<uint8_t> data)
  : data_(std::move(data)) {}

  std::string get_backend_type() const override
  {
    return "test";
  }

  size_t size() const override
  {
    return data_.size();
  }

  std::unique_ptr<rosidl::BufferImplBase<uint8_t>> to_cpu() const override
  {
    auto cpu = std::make_unique<rosidl::CpuBufferImpl<uint8_t>>();
    cpu->get_storage() = data_;
    return cpu;
  }

  std::unique_ptr<rosidl::BufferImplBase<uint8_t>> clone() const override
  {
    return std::make_unique<TestBufferImpl>(data_);
  }

private:
  std::vector<uint8_t> data_;
};

std::vector<uint8_t> serialize_to_bytes(const std::function<void(eprosima::fastcdr::Cdr &)> & fn)
{
  std::array<char, 4096> raw{};
  eprosima::fastcdr::FastBuffer fast_buffer(raw.data(), raw.size());
  eprosima::fastcdr::Cdr cdr(fast_buffer);
  fn(cdr);

  const auto serialized_len = cdr.get_serialized_data_length();
  return std::vector<uint8_t>(
    reinterpret_cast<uint8_t *>(raw.data()),
    reinterpret_cast<uint8_t *>(raw.data()) + serialized_len);
}

size_t endpoint_serialized_size(
  const rosidl::Buffer<uint8_t> & buffer,
  size_t current_alignment,
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext & serialization_context)
{
  const auto endpoint_info = rmw_get_zero_initialized_topic_endpoint_info();
  return rosidl_typesupport_fastrtps_cpp::get_buffer_serialized_size_with_endpoint(
    buffer, current_alignment, endpoint_info, serialization_context);
}

size_t serialize_endpoint_buffer(
  const rosidl::Buffer<uint8_t> & buffer,
  size_t prefix_size,
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext & serialization_context)
{
  eprosima::fastcdr::FastBuffer fast_buffer;
  eprosima::fastcdr::Cdr cdr(fast_buffer);
  const std::vector<uint8_t> prefix(prefix_size, 0u);
  if (!prefix.empty()) {
    cdr.serialize_array(prefix.data(), prefix.size());
  }
  const size_t initial_size = cdr.get_serialized_data_length();
  const auto endpoint_info = rmw_get_zero_initialized_topic_endpoint_info();
  rosidl_typesupport_fastrtps_cpp::serialize_buffer_with_endpoint(
    cdr, buffer, endpoint_info, serialization_context);
  return cdr.get_serialized_data_length() - initial_size;
}

rosidl_typesupport_fastrtps_cpp::BufferSerializationContext make_descriptor_context(
  bool accept_endpoint)
{
  rosidl_typesupport_fastrtps_cpp::BufferSerializationContext context;
  context.descriptor_ops["test"].create_descriptor_with_endpoint =
    [accept_endpoint](const void *, const rmw_topic_endpoint_info_t &)
    -> std::shared_ptr<void> {
      if (!accept_endpoint) {
        return nullptr;
      }
      return std::make_shared<std::vector<uint8_t>>(
        std::initializer_list<uint8_t>{1u, 2u, 3u, 4u, 5u});
    };
  auto & serializers = context.descriptor_serializers["test"];
  serializers.get_serialized_size = [](
    const std::shared_ptr<void> & descriptor,
    size_t current_alignment,
    const rmw_topic_endpoint_info_t &,
    const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext &) {
      const auto & data = *std::static_pointer_cast<std::vector<uint8_t>>(descriptor);
      constexpr size_t padding = 4;
      return eprosima::fastcdr::Cdr::alignment(current_alignment, padding) +
             padding + data.size();
    };
  serializers.serialize = [](
    eprosima::fastcdr::Cdr & cdr,
    const std::shared_ptr<void> & descriptor,
    const rmw_topic_endpoint_info_t &,
    const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext &) {
      cdr << *std::static_pointer_cast<std::vector<uint8_t>>(descriptor);
    };
  return context;
}

}  // namespace

TEST(BufferWireCompat, CpuBufferSerializationMatchesLegacyVectorBytes)
{
  const std::vector<uint8_t> payload{1, 2, 3, 4, 5, 6, 7, 8};

  rosidl::Buffer<uint8_t> buffer;
  buffer.resize(payload.size());
  for (size_t i = 0; i < payload.size(); ++i) {
    buffer[i] = payload[i];
  }

  const auto endpoint_info = rmw_get_zero_initialized_topic_endpoint_info();
  rosidl_typesupport_fastrtps_cpp::BufferSerializationContext serialization_context;

  const auto buffer_bytes = serialize_to_bytes(
    [&](eprosima::fastcdr::Cdr & cdr) {
      rosidl_typesupport_fastrtps_cpp::serialize_buffer_with_endpoint(
        cdr, buffer, endpoint_info, serialization_context);
    });

  const auto vector_bytes = serialize_to_bytes(
    [&](eprosima::fastcdr::Cdr & cdr) {
      cdr << payload;
    });

  EXPECT_EQ(buffer_bytes, vector_bytes);
}

TEST(BufferWireCompat, DeserializeLegacyVectorBytesIntoCpuBuffer)
{
  const std::vector<uint8_t> payload{11, 22, 33, 44, 55};
  auto bytes = serialize_to_bytes(
    [&](eprosima::fastcdr::Cdr & cdr) {
      cdr << payload;
    });

  eprosima::fastcdr::FastBuffer fast_buffer(
    reinterpret_cast<char *>(bytes.data()), bytes.size());
  eprosima::fastcdr::Cdr cdr(fast_buffer);
  rosidl::Buffer<uint8_t> output;
  const auto endpoint_info = rmw_get_zero_initialized_topic_endpoint_info();
  rosidl_typesupport_fastrtps_cpp::BufferSerializationContext serialization_context;

  rosidl_typesupport_fastrtps_cpp::deserialize_buffer_with_endpoint(
    cdr, output, endpoint_info, serialization_context);

  EXPECT_EQ(output.get_backend_type(), "cpu");
  EXPECT_EQ(output.to_vector(), payload);
}

TEST(BufferWireCompat, DescriptorMarkerIsNotInterpretedAsLegacyVector)
{
  auto bytes = serialize_to_bytes(
    [&](eprosima::fastcdr::Cdr & cdr) {
      cdr << static_cast<uint32_t>(rosidl_typesupport_fastrtps_cpp::kBufferDescriptorMarker1);
      cdr << static_cast<uint32_t>(rosidl_typesupport_fastrtps_cpp::kBufferDescriptorMarker2);
      cdr << std::string("demo");
    });

  eprosima::fastcdr::FastBuffer fast_buffer(
    reinterpret_cast<char *>(bytes.data()), bytes.size());
  eprosima::fastcdr::Cdr cdr(fast_buffer);
  rosidl::Buffer<uint8_t> output;
  const auto endpoint_info = rmw_get_zero_initialized_topic_endpoint_info();
  rosidl_typesupport_fastrtps_cpp::BufferSerializationContext serialization_context;

  bool result = rosidl_typesupport_fastrtps_cpp::deserialize_buffer_with_endpoint(
    cdr, output, endpoint_info, serialization_context);
  EXPECT_FALSE(result) <<
    "Expected descriptor path deserialization to fail for unregistered backend";
}

TEST(BufferSerializedSize, CpuPathMatchesSerializedLength)
{
  const rosidl::Buffer<uint8_t> buffer{1u, 2u, 3u, 4u, 5u};
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext context;

  EXPECT_EQ(
    endpoint_serialized_size(buffer, 0u, context),
    serialize_endpoint_buffer(buffer, 0u, context));
  EXPECT_EQ(
    endpoint_serialized_size(buffer, 3u, context),
    serialize_endpoint_buffer(buffer, 3u, context));
}

TEST(BufferSerializedSize, MissingBackendMatchesCpuFallbackLength)
{
  rosidl::Buffer<uint8_t> buffer(
    std::make_unique<TestBufferImpl>(std::vector<uint8_t>{1u, 2u, 3u}));
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext context;

  EXPECT_EQ(
    endpoint_serialized_size(buffer, 1u, context),
    serialize_endpoint_buffer(buffer, 1u, context));
}

TEST(BufferSerializedSize, RejectedEndpointMatchesCpuFallbackLength)
{
  rosidl::Buffer<uint8_t> buffer(
    std::make_unique<TestBufferImpl>(std::vector<uint8_t>{1u, 2u, 3u}));
  const auto context = make_descriptor_context(false);

  EXPECT_EQ(
    endpoint_serialized_size(buffer, 2u, context),
    serialize_endpoint_buffer(buffer, 2u, context));
}

TEST(BufferSerializedSize, AcceptedEndpointMatchesDescriptorLength)
{
  rosidl::Buffer<uint8_t> buffer(
    std::make_unique<TestBufferImpl>(std::vector<uint8_t>(1024u, 42u)));
  const auto context = make_descriptor_context(true);

  const size_t descriptor_size = endpoint_serialized_size(buffer, 3u, context);
  EXPECT_EQ(descriptor_size, serialize_endpoint_buffer(buffer, 3u, context));
  EXPECT_LT(descriptor_size, buffer.size());
}
