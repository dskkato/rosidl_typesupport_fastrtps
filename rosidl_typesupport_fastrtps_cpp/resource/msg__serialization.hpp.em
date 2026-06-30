@# Included from rosidl_typesupport_fastrtps_cpp/resource/idl__serialization.hpp.em
@{
from rosidl_generator_cpp import msg_type_only_to_cpp
from rosidl_parser.definition import AbstractGenericString
from rosidl_parser.definition import AbstractNestedType
from rosidl_parser.definition import AbstractSequence
from rosidl_parser.definition import AbstractWString
from rosidl_parser.definition import Array
from rosidl_parser.definition import BasicType
from rosidl_parser.definition import BoundedSequence
from rosidl_parser.definition import NamespacedType
from rosidl_parser.definition import UnboundedSequence
from rosidl_pycommon import convert_camel_case_to_lower_case_underscore

include_parts = [package_name] + list(interface_path.parents[0].parts) + [
    'detail', convert_camel_case_to_lower_case_underscore(interface_path.stem)]
include_base = '/'.join(include_parts)

nested_serialization_headers = []
for member in message.structure.members:
    type_ = member.type
    if isinstance(type_, AbstractNestedType):
        type_ = type_.value_type
    if isinstance(type_, NamespacedType):
        header_path = '/'.join(type_.namespaces + ['detail', convert_camel_case_to_lower_case_underscore(type_.name)]) + '__serialization.hpp'
        if header_path not in nested_serialization_headers:
            nested_serialization_headers.append(header_path)
}@

@[for header_path in nested_serialization_headers]@
#include "@(header_path)"
@[end for]@

@[for ns in message.structure.namespaced_type.namespaces]@
namespace @(ns)
{
@[end for]@

namespace typesupport_fastrtps_cpp
{

namespace detail
{

@{

def generate_member_for_cdr_serialize(member, suffix, endpoint_param=''):
  strlist = []
  strlist.append('// Member: %s' % (member.name))

  if isinstance(member.type, UnboundedSequence):
    if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint8':
      if suffix == '_with_endpoint':
        strlist.append('{')
        strlist.append('  rosidl_typesupport_fastrtps_cpp::serialize_buffer_with_endpoint(')
        strlist.append('    cdr, ros_message.%s, %s, serialization_context);' % (member.name, endpoint_param))
        strlist.append('}')
        return strlist
      strlist.append('{')
      strlist.append('  if (ros_message.%s.get_backend_type() == "cpu") {' % member.name)
      strlist.append('    const std::vector<%s> & vec = ros_message.%s;' % (msg_type_only_to_cpp(member.type.value_type), member.name))
      strlist.append('    cdr << vec;')
      strlist.append('  } else {')
      strlist.append('    std::vector<%s> vec = ros_message.%s.to_vector();' % (msg_type_only_to_cpp(member.type.value_type), member.name))
      strlist.append('    cdr << vec;')
      strlist.append('  }')
      strlist.append('}')
      return strlist

  nested_msg_suffix = suffix
  nested_extra_args = ', %s, serialization_context' % endpoint_param if suffix == '_with_endpoint' else ''
  if isinstance(member.type, AbstractNestedType):
    strlist.append('{')
    if isinstance(member.type, Array):
      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString)):
        strlist.append('  cdr << ros_message.%s;' % (member.name))
      else:
        strlist.append('  for (size_t i = 0; i < %d; i++) {' % (member.type.size))
        if isinstance(member.type.value_type, NamespacedType):
          strlist.append('    %s::typesupport_fastrtps_cpp::cdr_serialize%s(' % (('::'.join(member.type.value_type.namespaces)), nested_msg_suffix))
          strlist.append('      ros_message.%s[i],' % (member.name))
          strlist.append('      cdr%s);' % nested_extra_args)
        else:
          strlist.append('    rosidl_typesupport_fastrtps_cpp::cdr_serialize(cdr, ros_message.%s[i]);' % (member.name))
        strlist.append('  }')
    else:
      if isinstance(member.type, BoundedSequence) or isinstance(member.type.value_type, (NamespacedType, AbstractWString)):
        strlist.append('  size_t size = ros_message.%s.size();' % (member.name))
        if isinstance(member.type, BoundedSequence):
          strlist.append('  if (size > %d) {' % (member.type.maximum_size))
          strlist.append('    throw std::runtime_error("array size exceeds upper bound");')
          strlist.append('  }')
      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString)) and not isinstance(member.type, BoundedSequence):
        strlist.append('  cdr << ros_message.%s;' % (member.name))
      else:
        strlist.append('  cdr << static_cast<uint32_t>(size);')
        if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename not in ('boolean', 'wchar'):
          strlist.append('  if (size > 0) {')
          strlist.append('    cdr.serialize_array(&(ros_message.%s[0]), size);' % (member.name))
          strlist.append('  }')
        else:
          strlist.append('  for (size_t i = 0; i < size; i++) {')
          if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'boolean':
            strlist.append('    cdr << (ros_message.%s[i] ? true : false);' % (member.name))
          elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'wchar':
            strlist.append('    cdr << static_cast<wchar_t>(ros_message.%s[i]);' % (member.name))
          elif isinstance(member.type.value_type, AbstractWString):
            strlist.append('    rosidl_typesupport_fastrtps_cpp::cdr_serialize(cdr, ros_message.%s[i]);' % (member.name))
          elif not isinstance(member.type.value_type, NamespacedType):
            strlist.append('    cdr << ros_message.%s[i];' % (member.name))
          else:
            strlist.append('    %s::typesupport_fastrtps_cpp::detail::cdr_serialize_impl%s(' % (('::'.join(member.type.value_type.namespaces)), nested_msg_suffix))
            strlist.append('      ros_message.%s[i],' % (member.name))
            strlist.append('      cdr%s);' % nested_extra_args)
          strlist.append('  }')
    strlist.append('}')
  elif isinstance(member.type, BasicType) and member.type.typename == 'boolean':
    strlist.append('cdr << (ros_message.%s ? true : false);' % (member.name))
  elif isinstance(member.type, BasicType) and member.type.typename == 'wchar':
    strlist.append('cdr << static_cast<wchar_t>(ros_message.%s);' % (member.name))
  elif isinstance(member.type, AbstractWString):
    strlist.append('{')
    strlist.append('  rosidl_typesupport_fastrtps_cpp::cdr_serialize(cdr, ros_message.%s);' % (member.name))
    strlist.append('}')
  elif not isinstance(member.type, NamespacedType):
    strlist.append('cdr << ros_message.%s;' % (member.name))
  else:
    strlist.append('%s::typesupport_fastrtps_cpp::detail::cdr_serialize_impl%s(' % (('::'.join(member.type.namespaces)), nested_msg_suffix))
    strlist.append('  ros_message.%s,' % (member.name))
    strlist.append('  cdr%s);' % nested_extra_args)
  return strlist


def generate_member_for_get_serialized_size(member, suffix):
  strlist = []
  strlist.append('// Member: %s' % (member.name))

  if isinstance(member.type, AbstractNestedType):
    if isinstance(member.type, UnboundedSequence) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint8':
      strlist.append('current_alignment +=')
      strlist.append('  rosidl_typesupport_fastrtps_cpp::get_buffer_serialized_size(')
      strlist.append('  ros_message.%s, current_alignment);' % (member.name))
      return strlist

    strlist.append('{')
    if isinstance(member.type, Array):
      strlist.append('  size_t array_size = %d;' % (member.type.size))
    else:
      strlist.append('  size_t array_size = ros_message.%s.size();' % (member.name))
      if isinstance(member.type, BoundedSequence):
        strlist.append('  if (array_size > %d) {' % (member.type.maximum_size))
        strlist.append('    throw std::runtime_error("array size exceeds upper bound");')
        strlist.append('  }')
      strlist.append('  current_alignment += padding +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, padding);')
    if isinstance(member.type.value_type, AbstractGenericString):
      strlist.append('  for (size_t index = 0; index < array_size; ++index) {')
      strlist.append('    current_alignment += padding +')
      strlist.append('      eprosima::fastcdr::Cdr::alignment(current_alignment, padding) +')
      if isinstance(member.type.value_type, AbstractWString):
        strlist.append('      wchar_size *')
      strlist.append('      (ros_message.%s[index].size() + 1);' % (member.name))
      strlist.append('  }')
    elif isinstance(member.type.value_type, BasicType):
      strlist.append('  size_t item_size = sizeof(ros_message.%s[0]);' % (member.name))
      strlist.append('  current_alignment += array_size * item_size +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, item_size);')
    else:
      strlist.append('  for (size_t index = 0; index < array_size; ++index) {')
      strlist.append('    current_alignment +=')
      strlist.append('      %s::typesupport_fastrtps_cpp::detail::get_serialized_size_impl%s(' % (('::'.join(member.type.value_type.namespaces)), suffix))
      strlist.append('      ros_message.%s[index], current_alignment);' % (member.name))
      strlist.append('  }')
    strlist.append('}')
  else:
    if isinstance(member.type, AbstractGenericString):
      strlist.append('current_alignment += padding +')
      strlist.append('  eprosima::fastcdr::Cdr::alignment(current_alignment, padding) +')
      if isinstance(member.type, AbstractWString):
        strlist.append('  wchar_size *')
      strlist.append('  (ros_message.%s.size() + 1);' % (member.name))
    elif isinstance(member.type, BasicType):
      strlist.append('{')
      strlist.append('  size_t item_size = sizeof(ros_message.%s);' % (member.name))
      strlist.append('  current_alignment += item_size +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, item_size);')
      strlist.append('}')
    else:
      strlist.append('current_alignment +=')
      strlist.append('  %s::typesupport_fastrtps_cpp::detail::get_serialized_size_impl%s(' % (('::'.join(member.type.namespaces)), suffix))
      strlist.append('  ros_message.%s, current_alignment);' % (member.name))

  return strlist


def generate_member_for_max_serialized_size(member, suffix):
  strlist = []
  strlist.append('// Member: %s' % (member.name))
  strlist.append('{')

  if isinstance(member.type, AbstractNestedType):
    if isinstance(member.type, Array):
      strlist.append('  size_t array_size = %d;' % (member.type.size))
    elif isinstance(member.type, BoundedSequence):
      strlist.append('  size_t array_size = %d;' % (member.type.maximum_size))
    else:
      strlist.append('  size_t array_size = 0;')
      strlist.append('  full_bounded = false;')
    if isinstance(member.type, AbstractSequence):
      strlist.append('  is_plain = false;')
      strlist.append('  current_alignment += padding +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, padding);')
  else:
    strlist.append('  size_t array_size = 1;')

  type_ = member.type
  if isinstance(type_, AbstractNestedType):
    type_ = type_.value_type

  if isinstance(type_, AbstractGenericString):
    strlist.append('  full_bounded = false;')
    strlist.append('  is_plain = false;')
    strlist.append('  for (size_t index = 0; index < array_size; ++index) {')
    strlist.append('    current_alignment += padding +')
    strlist.append('      eprosima::fastcdr::Cdr::alignment(current_alignment, padding) +')
    if type_.has_maximum_size():
      if isinstance(type_, AbstractWString):
        strlist.append('      wchar_size *')
      strlist.append('      %d +' % (type_.maximum_size))
    if isinstance(type_, AbstractWString):
      strlist.append('      wchar_size *')
    strlist.append('      1;')
    strlist.append('  }')
  elif isinstance(type_, BasicType):
    if type_.typename in ('boolean', 'octet', 'char', 'uint8', 'int8'):
      strlist.append('  last_member_size = array_size * sizeof(uint8_t);')
      strlist.append('  current_alignment += array_size * sizeof(uint8_t);')
    elif type_.typename in ('wchar', 'int16', 'uint16'):
      strlist.append('  last_member_size = array_size * sizeof(uint16_t);')
      strlist.append('  current_alignment += array_size * sizeof(uint16_t) +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, sizeof(uint16_t));')
    elif type_.typename in ('int32', 'uint32', 'float'):
      strlist.append('  last_member_size = array_size * sizeof(uint32_t);')
      strlist.append('  current_alignment += array_size * sizeof(uint32_t) +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, sizeof(uint32_t));')
    elif type_.typename in ('int64', 'uint64', 'double'):
      strlist.append('  last_member_size = array_size * sizeof(uint64_t);')
      strlist.append('  current_alignment += array_size * sizeof(uint64_t) +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, sizeof(uint64_t));')
    elif type_.typename == 'long double':
      strlist.append('  last_member_size = array_size * sizeof(long double);')
      strlist.append('  current_alignment += array_size * sizeof(long double) +')
      strlist.append('    eprosima::fastcdr::Cdr::alignment(current_alignment, sizeof(long double));')
  else:
    strlist.append('  last_member_size = 0;')
    strlist.append('  for (size_t index = 0; index < array_size; ++index) {')
    strlist.append('    bool inner_full_bounded;')
    strlist.append('    bool inner_is_plain;')
    strlist.append('    size_t inner_size =')
    strlist.append('      %s::typesupport_fastrtps_cpp::detail::max_serialized_size_impl%s_%s(' % (('::'.join(type_.namespaces)), suffix, type_.name))
    strlist.append('      inner_full_bounded, inner_is_plain, current_alignment);')
    strlist.append('    last_member_size += inner_size;')
    strlist.append('    current_alignment += inner_size;')
    strlist.append('    full_bounded &= inner_full_bounded;')
    strlist.append('    is_plain &= inner_is_plain;')
    strlist.append('  }')
  strlist.append('}')
  return strlist
}@

inline bool
cdr_serialize_impl(
  const @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  eprosima::fastcdr::Cdr & cdr)
{
@[for member in message.structure.members]@
@[  for line in generate_member_for_cdr_serialize(member, '')]@
  @(line)
@[  end for]@

@[end for]@
  return true;
}

inline bool
cdr_deserialize_impl(
  eprosima::fastcdr::Cdr & cdr,
  @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message)
{
@[for member in message.structure.members]@
  // Member: @(member.name)
@[  if isinstance(member.type, AbstractNestedType)]@
  {
@[    if isinstance(member.type, Array)]@
@[      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString))]@
    cdr >> ros_message.@(member.name);
@[      else]@
    for (size_t i = 0; i < @(member.type.size); i++) {
@[        if isinstance(member.type.value_type, NamespacedType)]@
      @('::'.join(member.type.value_type.namespaces))::typesupport_fastrtps_cpp::cdr_deserialize(
        cdr,
        ros_message.@(member.name)[i]);
@[        else]@
      bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name)[i]);
      if (!succeeded) {
        fprintf(stderr, "failed to deserialize u16string\n");
        return false;
      }
@[        end if]@
    }
@[      end if]@
@[    else]@
@[      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString)) and not isinstance(member.type, BoundedSequence)]@
    cdr >> ros_message.@(member.name);
@[      else]@
    uint32_t cdrSize;
    cdr >> cdrSize;
    size_t size = static_cast<size_t>(cdrSize);

    auto old_state = cdr.get_state();
    bool correct_size = cdr.jump(size);
    cdr.set_state(old_state);
    if (!correct_size) {
      fprintf(stderr, "sequence size exceeds remaining buffer\n");
      return false;
    }

    ros_message.@(member.name).resize(size);
@[        if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename not in ('boolean', 'wchar')]@
    if (size > 0) {
      cdr.deserialize_array(&(ros_message.@(member.name)[0]), size);
    }
@[        else]@
    for (size_t i = 0; i < size; i++) {
@[            if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'boolean']@
      uint8_t tmp;
      cdr >> tmp;
      ros_message.@(member.name)[i] = tmp ? true : false;
@[            elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'wchar']@
      wchar_t tmp;
      cdr >> tmp;
      ros_message.@(member.name)[i] = static_cast<char16_t>(tmp);
@[            elif isinstance(member.type.value_type, AbstractWString)]@
      bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name)[i]);
      if (!succeeded) {
        fprintf(stderr, "failed to deserialize u16string\n");
        return false;
      }
@[            elif not isinstance(member.type.value_type, NamespacedType)]@
      cdr >> ros_message.@(member.name)[i];
@[            else]@
      @('::'.join(member.type.value_type.namespaces))::typesupport_fastrtps_cpp::cdr_deserialize(
        cdr, ros_message.@(member.name)[i]);
@[            end if]@
    }
@[          end if]@
@[      end if]@
@[    end if]@
  }
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'boolean']@
  {
    uint8_t tmp;
    cdr >> tmp;
    ros_message.@(member.name) = tmp ? true : false;
  }
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'wchar']@
  {
    wchar_t tmp;
    cdr >> tmp;
    ros_message.@(member.name) = static_cast<char16_t>(tmp);
  }
@[  elif isinstance(member.type, AbstractWString)]@
  {
    bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name));
    if (!succeeded) {
      fprintf(stderr, "failed to deserialize u16string\n");
      return false;
    }
  }
@[  elif not isinstance(member.type, NamespacedType)]@
  cdr >> ros_message.@(member.name);
@[  else]@
  @('::'.join(member.type.namespaces))::typesupport_fastrtps_cpp::detail::cdr_deserialize_impl(
    cdr, ros_message.@(member.name));
@[  end if]@

@[end for]@
  return true;
}

inline bool
cdr_serialize_with_endpoint_impl(
  const @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  eprosima::fastcdr::Cdr & cdr,
  const rmw_topic_endpoint_info_t & endpoint_info,
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext & serialization_context)
{
  try {
@[for member in message.structure.members]@
@[  for line in generate_member_for_cdr_serialize(member, '_with_endpoint', 'endpoint_info')]@
    @(line)
@[  end for]@
@[end for]@
  } catch (const std::exception & e) {
    RCUTILS_LOG_ERROR_NAMED(
      "@(package_name).typesupport_fastrtps_cpp",
      "cdr_serialize_with_endpoint failed: %s", e.what());
    return false;
  }
  return true;
}

inline bool
cdr_deserialize_with_endpoint_impl(
  eprosima::fastcdr::Cdr & cdr,
  @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  const rmw_topic_endpoint_info_t & endpoint_info,
  const rosidl_typesupport_fastrtps_cpp::BufferSerializationContext & serialization_context)
{
@[for member in message.structure.members]@
  // Member: @(member.name)
@[  if isinstance(member.type, UnboundedSequence) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint8']@
  {
    if (!rosidl_typesupport_fastrtps_cpp::deserialize_buffer_with_endpoint(
        cdr, ros_message.@(member.name), endpoint_info, serialization_context))
    {
      RCUTILS_LOG_ERROR_NAMED(
        "@(package_name).typesupport_fastrtps_cpp",
        "cdr_deserialize_with_endpoint: failed to deserialize '@(member.name)'\n");
      return false;
    }
  }
@[  elif isinstance(member.type, AbstractNestedType)]@
  {
@[    if isinstance(member.type, Array)]@
@[      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString))]@
    cdr >> ros_message.@(member.name);
@[      else]@
    for (size_t i = 0; i < @(member.type.size); i++) {
@[        if isinstance(member.type.value_type, NamespacedType)]@
      @('::'.join(member.type.value_type.namespaces))::typesupport_fastrtps_cpp::cdr_deserialize_with_endpoint(
        cdr,
        ros_message.@(member.name)[i],
        endpoint_info,
        serialization_context);
@[        else]@
      bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name)[i]);
      if (!succeeded) {
        fprintf(stderr, "failed to deserialize u16string\n");
        return false;
      }
@[        end if]@
    }
@[      end if]@
@[    else]@
@[      if not isinstance(member.type.value_type, (NamespacedType, AbstractWString)) and not isinstance(member.type, BoundedSequence)]@
    cdr >> ros_message.@(member.name);
@[      else]@
    uint32_t cdrSize;
    cdr >> cdrSize;
    size_t size = static_cast<size_t>(cdrSize);

    auto old_state = cdr.get_state();
    bool correct_size = cdr.jump(size);
    cdr.set_state(old_state);
    if (!correct_size) {
      fprintf(stderr, "sequence size exceeds remaining buffer\n");
      return false;
    }

    ros_message.@(member.name).resize(size);
@[        if isinstance(member.type, BoundedSequence)]@
    if (size > @(member.type.maximum_size)) {
      throw std::runtime_error("vector size exceeds upper bound");
    }
@[        end if]@
@[        if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename not in ('boolean', 'wchar')]@
    if (size > 0) {
      cdr.deserialize_array(&(ros_message.@(member.name)[0]), size);
    }
@[        else]@
    for (size_t i = 0; i < size; i++) {
@[          if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'boolean']@
      uint8_t tmp;
      cdr >> tmp;
      ros_message.@(member.name)[i] = tmp ? true : false;
@[          elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'wchar']@
      wchar_t tmp;
      cdr >> tmp;
      ros_message.@(member.name)[i] = static_cast<char16_t>(tmp);
@[          elif isinstance(member.type.value_type, AbstractWString)]@
      bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name)[i]);
      if (!succeeded) {
        fprintf(stderr, "failed to deserialize u16string\n");
        return false;
      }
@[          elif not isinstance(member.type.value_type, NamespacedType)]@
      cdr >> ros_message.@(member.name)[i];
@[          else]@
      @('::'.join(member.type.value_type.namespaces))::typesupport_fastrtps_cpp::cdr_deserialize_with_endpoint(
        cdr,
        ros_message.@(member.name)[i],
        endpoint_info,
        serialization_context);
@[          end if]@
    }
@[        end if]@
@[      end if]@
@[    end if]@
  }
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'boolean']@
  cdr >> ros_message.@(member.name);
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'wchar']@
  {
    uint16_t wchar_value;
    cdr >> wchar_value;
    ros_message.@(member.name) = static_cast<wchar_t>(wchar_value);
  }
@[  elif isinstance(member.type, AbstractWString)]@
  {
    bool succeeded = rosidl_typesupport_fastrtps_cpp::cdr_deserialize(cdr, ros_message.@(member.name));
    if (!succeeded) {
      fprintf(stderr, "failed to deserialize u16string\n");
      return false;
    }
  }
@[  elif not isinstance(member.type, NamespacedType)]@
  cdr >> ros_message.@(member.name);
@[  else]@
  @('::'.join(member.type.namespaces))::typesupport_fastrtps_cpp::detail::cdr_deserialize_with_endpoint_impl(
    cdr,
    ros_message.@(member.name),
    endpoint_info,
    serialization_context);
@[  end if]@

@[end for]@
  return true;
}

inline size_t
get_serialized_size_impl(
  const @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  size_t current_alignment)
{
  size_t initial_alignment = current_alignment;

  const size_t padding = 4;
  const size_t wchar_size = 4;
  (void)padding;
  (void)wchar_size;

@[for member in message.structure.members]@
@[  for line in generate_member_for_get_serialized_size(member, '')]@
  @(line)
@[  end for]@

@[end for]@
  return current_alignment - initial_alignment;
}

inline size_t
max_serialized_size_impl_@(message.structure.namespaced_type.name)(
  bool & full_bounded,
  bool & is_plain,
  size_t current_alignment)
{
  size_t initial_alignment = current_alignment;

  const size_t padding = 4;
  const size_t wchar_size = 4;
  size_t last_member_size = 0;
  (void)last_member_size;
  (void)padding;
  (void)wchar_size;

  full_bounded = true;
  is_plain = true;

@{
last_member_name_ = None
}@
@[for member in message.structure.members]@
@{
last_member_name_ = member.name
}@
@[  for line in generate_member_for_max_serialized_size(member, '')]@
  @(line)
@[  end for]@
@[end for]@

  size_t ret_val = current_alignment - initial_alignment;
@[if last_member_name_ is not None]@
  if (is_plain) {
    using DataType = @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name]));
    is_plain =
      (
      offsetof(DataType, @(last_member_name_)) +
      last_member_size
      ) == ret_val;
  }

@[end if]@
  return ret_val;
}

inline bool
cdr_serialize_key_impl(
  const @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  eprosima::fastcdr::Cdr & cdr)
{
@[for member in message.structure.members]@
@[  if not member.has_annotation('key') and message.structure.has_any_member_with_annotation('key')]@
@[  continue]@
@[  end if]@
@[  for line in generate_member_for_cdr_serialize(member, '_key')]@
  @(line)
@[  end for]@

@[end for]@
  return true;
}

inline size_t
get_serialized_size_key_impl(
  const @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name])) & ros_message,
  size_t current_alignment)
{
  size_t initial_alignment = current_alignment;

  const size_t padding = 4;
  const size_t wchar_size = 4;
  (void)padding;
  (void)wchar_size;

@[for member in message.structure.members]@
@[  if not member.has_annotation('key') and message.structure.has_any_member_with_annotation('key')]@
@[  continue]@
@[  end if]@
@[  for line in generate_member_for_get_serialized_size(member, '_key')]@
  @(line)
@[  end for]@

@[end for]@
  return current_alignment - initial_alignment;
}

inline size_t
max_serialized_size_key_impl_@(message.structure.namespaced_type.name)(
  bool & full_bounded,
  bool & is_plain,
  size_t current_alignment)
{
  size_t initial_alignment = current_alignment;

  const size_t padding = 4;
  const size_t wchar_size = 4;
  size_t last_member_size = 0;
  (void)last_member_size;
  (void)padding;
  (void)wchar_size;

  full_bounded = true;
  is_plain = true;

@{
last_member_name_ = None
}@
@[for member in message.structure.members]@
@{
last_member_name_ = member.name
}@
@[  if not member.has_annotation('key') and message.structure.has_any_member_with_annotation('key')]@
@[  continue]@
@[  end if]@
@[  for line in generate_member_for_max_serialized_size(member, '_key')]@
  @(line)
@[  end for]@
@[end for]@

  size_t ret_val = current_alignment - initial_alignment;
@[if last_member_name_ is not None]@
  if (is_plain) {
    using DataType = @('::'.join([package_name] + list(interface_path.parents[0].parts) + [message.structure.namespaced_type.name]));
    is_plain =
      (
      offsetof(DataType, @(last_member_name_)) +
      last_member_size
      ) == ret_val;
  }

@[end if]@
  return ret_val;
}

}  // namespace detail

inline bool
has_buffer_fields_@(message.structure.namespaced_type.name)()
{
  return false;
}

}  // namespace typesupport_fastrtps_cpp

@[for ns in reversed(message.structure.namespaced_type.namespaces)]@
}  // namespace @(ns)
@[end for]@
