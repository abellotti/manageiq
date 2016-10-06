module Api
  class ServiceDialogsController < BaseController
    def show
      if params[:c_id]
        resource = Dialog.find(params[:c_id])
        render :json => single_resource(resource, params).target!
      else
        render :json => dialog_collection(params).target!
      end
    end

    def refresh_dialog_fields_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Reconfiguring a #{type} resource" unless id

      api_action(type, id) do |klass|
        service_dialog = resource_search(id, type, klass)
        api_log_info("Refreshing Dialog Fields for #{service_dialog_ident(service_dialog)}")

        refresh_dialog_fields_service_dialog(service_dialog, data)
      end
    end

    private

    def single_resource(resource, params, type = :service_dialogs, reftype = :service_dialogs)
      json = resource_to_jbuilder(type, reftype, resource)
      expand_dialog_content(json, resource) unless params.key?(:attributes)
      json
    end

    def dialog_collection(params = {})
      dialogs = Dialog.all
      Jbuilder.new do |json|
        json.ignore_nil!
        json.set! 'name', 'service_dialogs'
        json.set! 'count', dialogs.count
        json.set! 'subcount', dialogs.count
        json.resources dialogs.collect do |resource|
          if params['expand'] == 'resources'
            add_hash json, single_resource(resource, params).attributes!
          else
            json.href normalize_href(:service_dialogs, resource['id'])
          end
        end
      end
    end

    def refresh_dialog_fields_service_dialog(service_dialog, data)
      data ||= {}
      dialog_fields = Hash(data["dialog_fields"])
      refresh_fields = data["fields"]
      return action_result(false, "Must specify fields to refresh") if refresh_fields.blank?

      define_service_dialog_fields(service_dialog, dialog_fields)

      refresh_dialog_fields_action(service_dialog, refresh_fields, service_dialog_ident(service_dialog))
    rescue => err
      action_result(false, err.to_s)
    end

    def define_service_dialog_fields(service_dialog, dialog_fields)
      ident = service_dialog_ident(service_dialog)
      dialog_fields.each do |key, value|
        dialog_field = service_dialog.field(key)
        raise BadRequestError, "Dialog field #{key} specified does not exist in #{ident}" if dialog_field.nil?
        dialog_field.value = value
      end
    end

    def expand_dialog_content(json, resource)
      content = {
        'content' => resource.content(nil, nil, true)
      }
      add_hash json, content
    end

    def service_dialog_ident(service_dialog)
      "Service Dialog id:#{service_dialog.id} label:'#{service_dialog.label}'"
    end
  end
end
