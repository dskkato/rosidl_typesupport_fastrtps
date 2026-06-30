// generated from rosidl_typesupport_fastrtps_cpp/resource/idl__serialization.hpp.em
// with input from @(package_name):@(interface_path)
// generated code does not contain a copyright notice
@
@#######################################################################
@# EmPy template for generating <idl>__serialization.hpp files
@#
@# Context:
@#  - package_name (string)
@#  - interface_path (Path relative to the directory named after the package)
@#  - content (IdlContent, list of elements, e.g. Messages or Services)
@#######################################################################
@
@{
from rosidl_pycommon import convert_camel_case_to_lower_case_underscore
include_parts = [package_name] + list(interface_path.parents[0].parts) + [
    'detail', convert_camel_case_to_lower_case_underscore(interface_path.stem)]
include_base = '/'.join(include_parts)
}@
#ifndef @(include_base.upper().replace('/', '_').replace('-', '_'))__SERIALIZATION_HPP_
#define @(include_base.upper().replace('/', '_').replace('-', '_'))__SERIALIZATION_HPP_

@{
header_files = [
    'cstddef',
    'cstdio',
    'limits',
    'stdexcept',
    'string',
    'rcutils/logging_macros.h',
    'rosidl_typesupport_fastrtps_cpp/buffer_serialization.hpp',
    'rosidl_typesupport_fastrtps_cpp/serialization_helpers.hpp',
    include_base + '__struct.hpp',
    'fastcdr/Cdr.h',
]
}@
@[for header_file in header_files]@
#include "@(header_file)"
@[end for]@

@{
from rosidl_parser.definition import Message
from rosidl_parser.definition import Service
from rosidl_parser.definition import Action
}@
@{
for message in content.get_elements_of_type(Message):
    TEMPLATE(
        'msg__serialization.hpp.em',
        package_name=package_name, interface_path=interface_path, message=message)
for service in content.get_elements_of_type(Service):
    pass
for action in content.get_elements_of_type(Action):
    TEMPLATE(
        'msg__serialization.hpp.em',
        package_name=package_name, interface_path=interface_path, message=action.goal)
    TEMPLATE(
        'msg__serialization.hpp.em',
        package_name=package_name, interface_path=interface_path, message=action.result)
    TEMPLATE(
        'msg__serialization.hpp.em',
        package_name=package_name, interface_path=interface_path, message=action.feedback)
}@

#endif  // @(include_base.upper().replace('/', '_').replace('-', '_'))__SERIALIZATION_HPP_
