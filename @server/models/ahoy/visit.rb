class Ahoy::Visit < ApplicationRecord
  acts_as_tenant :subdomain  
  
  self.table_name = "ahoy_visits"

  has_many :events, class_name: "Ahoy::Event"
  belongs_to :user, optional: true

  class_attribute :my_public_fields
  self.my_public_fields = [:browser, :ip, :device_type, :landing_page, :referring_domain, :started_at, :user_id, :utm_source]

  def as_json(options={})
    options[:only] ||= Ahoy::Visit.my_public_fields
    result = super(options)

    anonymize_everything = current_subdomain.customizations['anonymize_everything']

    if anonymize_everything
      result['user_id'] = User.anonymized_id(result['user_id'])
    end

    stubify_field(result, 'user')
    result
  end



end
