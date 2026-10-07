class Services::Update
  extend LightService::Action

  expects :service, :params
  promises :service

  executed do |context|
    was_public = context.service.allow_public_networking?

    unless context.service.update(Service.permitted_params(context.params))
      context.fail_and_return!(context.service.errors.full_messages.to_sentence)
    end
    if context.service.cron_job? && context.params[:service][:cron_schedule].present?
      context.service.cron_schedule.update(
        context.params[:service][:cron_schedule].permit(:schedule))
    end

    if !was_public && context.service.allow_public_networking?
      Domains::AttachAutoManagedDomain.execute(service: context.service)
    end

    context.service.updated!
  end
end
