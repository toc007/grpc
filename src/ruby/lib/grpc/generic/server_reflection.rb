this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(File.dirname(this_dir), 'generic', 'reflection')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

p $LOAD_PATH[0]

# require 'reflection_pb'
# require 'reflection_services_pb'
# require_relative './reflection/reflection_pb.rb'
# require_relative './reflection/reflection_services_pb.rb'
require_relative './reflection/reflection_pb.rb'
require_relative './reflection/reflection_services_pb.rb'
require 'google/protobuf'

# ReflectionServer implements the ServerReflection template
class ReflectionServer < Grpc::Reflection::V1alpha::ServerReflection::Service
  @rpc_descs
  @rpc_handlers

  # def initialize
  #   p "initialize invoked!"
  #   puts caller
  # end

  def self.set_descs(rpc_descs)
    p "entering set_descs"
    @rpc_descs = rpc_descs.dup
    @rpc_descs.freeze
    p "exiting set_descs"
  end

  def self.set_handlers(rpc_handlers)
    p "entering set_handlers"
    @rpc_handlers = rpc_handlers.dup
    @rpc_handlers.freeze
    p "exiting set_handlers"
  end

  def server_reflection_info(reflect_req)
    p "server_reflection_info says hello!!"
    ReflectionEnumerator.new(reflect_req, @rpc_descs, @rpc_handlers).each_item
  end

end

class ReflectionEnumerator
  @requests
  @rpc_descs
  @rpc_handlers
  def initialize(reflect_reqs, rpc_descs, rpc_handlers)
    p "ReflectionEnumerator initialized"
    @requests = reflect_reqs
    @rpc_descs = rpc_descs
    @rpc_handlers = rpc_handlers
  end

  def each_item
    p "Inside ReflectionEnumerator.each_item"
    return enum_for(:each_item) unless block_given?
    begin
      # send back the earlier messages at this point
      @requests.each do |r|
        if r.instance_of? Grpc::Reflection::V1alpha::ServerReflectionRequest
          p "\tHey I found a ServerReflectionRequest"
          p r
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
    p "\t\tinside handle_request"
    p request.message_request
    resp = Grpc::Reflection::V1alpha::ServerReflectionResponse.new()
    case request.message_request
    when :file_by_filename
      p "file_by_filename"
    when :file_containing_symbol
      p "file_containing_symbol"
    when :file_containing_extension
      p "file_containing_extension"
    when :all_extension_numbers_of_type
      p "all_extension_numbers_of_type"
    when :list_services
      p "list_services"
    else
      p "malformed request, does not have message_request set"
    end
    return resp
  end
end
