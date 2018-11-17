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

$services = []
$rpc_descs
$rpc_handlers
$pool

# ReflectionServer implements the ServerReflection template
class ReflectionServer < Grpc::Reflection::V1alpha::ServerReflection::Service

  def self._init(rpc_descs, rpc_handlers)
    $rpc_descs = rpc_descs.dup
    $rpc_descs.freeze

    $rpc_handlers = rpc_handlers.dup
    $rpc_handlers.freeze

    $rpc_descs.each_key do |service|
      service = service.to_s
      # strip out the first /
      service[0] = ""
      service.sub!("/", ".")
      $services << service
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
        if r.instance_of? Grpc::Reflection::V1alpha::ServerReflectionRequest
          yield handle_request(r)
        else
          p "\tHey!! This isn't a ServerReflectionRequest (╯°□°）╯︵ ┻━┻"
          err = Grpc::Reflection::V1alpha::ErrorResponse.new(
            :error_code => 1,
            :error_message => "Expected a ServerReflectionRequest"
          )
          yield Grpc::Reflection::V1alpha::ServerReflectionResponse.new(
            :original_request => r,
            :message_response => err
          )
        end

        # # Create a ServiceResponse
        # #   User specified or auto generated?
        # service_names = ["hello", "world"]
        # services = service_names.map do |s|
        #   Grpc::Reflection::V1alpha::ServiceResponse.new(:name => s)
        # end

        # serviceResponse = Grpc::Reflection::V1alpha::ListServiceResponse.new(
        #   :service => services
        # )

        # response = Grpc::Reflection::V1alpha::ServerReflectionResponse.new(
        #   :valid_host => "ruby_reflection_server",
        #   :original_request => r,
        #   :list_services_response => serviceResponse
        # )
        # yield response
      end
    rescue StandardError => e
      fail e # signal completion via an error
    end
  end

  def handle_request(request)
    resp = Grpc::Reflection::V1alpha::ServerReflectionResponse.new()
    resp["original_request"] = request
    case request.message_request
    when :file_by_filename
      p "file_by_filename: #{request.file_by_filename}"
      $pool.lookup(request.file_by_filename)
      # respond with a file_descriptro_response
      
    when :file_containing_symbol
      p "file_containing_symbol: #{request.file_containing_symbol}"

    when :file_containing_extension
      p "file_containing_extension: #{request.file_containing_extension}"

    when :all_extension_numbers_of_type
      p "all_extension_numbers_of_type: #{request.all_extension_numbers_of_type}"

    when :list_services
      p "inside list_services"
      p "list_services: #{request.list_services}"
      p "Registered services: #{$services}"

      service_response = $services.map do |service|
        Grpc::Reflection::V1alpha::ServiceResponse.new(:name => service)
      end
      p "service_response: #{service_response}"
      
      list_services_response = 
        Grpc::Reflection::V1alpha::ListServiceResponse.new(
          :service => service_response)
      p "list_services_response: #{list_services_response}"

      resp["list_services_response"] = list_services_response
    else
      p "malformed request, does not have message_request set"
      err = Grpc::Reflection::V1alpha::ErrorResponse.new(
        :error_code => 1,
        :error_message => "Expected a ServerReflectionRequest"
      )
      resp["error_response"] = err
    end
    return resp
    puts "\n"
  end
end
