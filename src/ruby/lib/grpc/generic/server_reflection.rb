this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(File.dirname(this_dir), 'generic', 'reflection')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

# require 'reflection_pb'
# require 'reflection_services_pb'
# require_relative './reflection/reflection_pb.rb'
# require_relative './reflection/reflection_services_pb.rb'
require_relative './reflection/reflection_pb.rb'
require_relative './reflection/reflection_services_pb.rb'
require 'google/protobuf'

include Grpc::Reflection::V1alpha

$services = {}
$rpc_descs
$rpc_handlers
$pool

# ReflectionServer implements the ServerReflection template
class ReflectionServer < ServerReflection::Service

  def self._init(rpc_descs, rpc_handlers)
    $rpc_descs = rpc_descs.dup
    $rpc_descs.freeze

    $rpc_descs.each_pair do |route, desc|
      p route
      p desc
    end

    $rpc_handlers = rpc_handlers.dup
    $rpc_handlers.freeze

    $rpc_descs.each_key do |package|
      package = package.to_s
      # strip out the first /
      package[0] = ""
      package, service = package.split("/")
      if $services.has_key? package
        $services[package] << service
      else
        $services[package] = [service]
      end
    end
    $services.sort
    $services.freeze

    $pool = Google::Protobuf::DescriptorPool.generated_pool
    #$services.each {|x| p $pool.lookup(x)}
  end

  def server_reflection_info(reflect_req)
    ReflectionEnumerator.new(reflect_req).each_item
  end

end

class ReflectionEnumerator
  @requests
  def initialize(reflect_reqs)
    @requests = reflect_reqs
  end

  def each_item
    p "Inside ReflectionEnumerator.each_item"
    return enum_for(:each_item) unless block_given?
    begin
      # send back the earlier messages at this point
      @requests.each do |r|
        if r.instance_of? ServerReflectionRequest
          yield handle_request(r)
        else
          p "\tHey!! This isn't a ServerReflectionRequest (╯°□°）╯︵ ┻━┻"
          invalid_arg = GRPC::InvalidArgument.new(
            details = "Expected a ServerReflectionRequest"
          )
          err = ErrorResponse.new(
            :error_code => invalid_arg.code,
            :error_message => invalid_arg.details
          )
          resp["error_response"] = err
          yield resp
        end
      end
    rescue StandardError => e
      fail e # signal completion via an error
    end
  end

  def handle_request(request)
    resp = ServerReflectionResponse.new()
    resp["original_request"] = request
    case request.message_request
    when :file_by_filename
      p "file_by_filename: #{request.file_by_filename}"
      # respond with a file_descriptro_response

    when :file_containing_symbol
      p "file_containing_symbol: #{request.file_containing_symbol}"
      req_package = request.file_containing_symbol
      if $services.has_key? req_package
        methods = $services[req_package]
        methods.each do |method|
          p "looking up #{req_package}.#{method}"
          route = "/"+req_package+"/"+method
          route = route.to_sym
          p $rpc_descs[route]
          p req_descriptor
          p req_descriptor.name
          p req_descriptor.file_descriptor
          req_descriptor.each do |x|
            p x
          end
        end
      else
        p "#{req_package} not a registered service"
      end
    when :file_containing_extension
      p "file_containing_extension: #{request.file_containing_extension}"

    when :all_extension_numbers_of_type
      p "all_extension_numbers_of_type: #{request.all_extension_numbers_of_type}"

    when :list_services
      p "list_services: #{request.list_services}"

      service_response = $services.keys.map do |package|
        ServiceResponse.new(:name => package)
      end

      list_services_response = 
        ListServiceResponse.new(:service => service_response)

      resp["list_services_response"] = list_services_response

    else
      p "malformed request, does not have message_request set"
      invalid_arg = GRPC::InvalidArgument.new(
        details = "Expected a ServerReflectionRequest"
      )
      err = ErrorResponse.new(
        :error_code => invalid_arg.code,
        :error_message => invalid_arg.details
      )
      resp["error_response"] = err
    end
    return resp
  end
end
