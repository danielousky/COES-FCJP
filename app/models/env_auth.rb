# == Schema Information
#
# Table name: env_auths
#
#  id                    :bigint           not null, primary key
#  env_authorizable_type :string           default("School")
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  admin_id              :bigint           not null
#  env_authorizable_id   :bigint
#
# Indexes
#
#  index_env_auths_on_admin_id          (admin_id)
#  index_env_auths_on_env_authorizable  (env_authorizable_type,env_authorizable_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_id => admins.user_id) ON DELETE => cascade ON UPDATE => cascade
#
class EnvAuth < ApplicationRecord
    
    belongs_to :env_authorizable, polymorphic: true, optional: true

    belongs_to :admin

    validates :admin, presence: true
    validates :env_authorizable, presence: true
    # validates_uniqueness_of :env_authorizable_type, scope: :env_authorizable_id, message: 'Asociación ya creada', field_name: false
    validates_with SameTypesValidator, field_name: false  


    def name
        "#{ApplicationController.helpers.translate_model(env_authorizable_type.downcase, 'one')}: #{env_authorizable.name}"
    end
    rails_admin do
        visible false

        edit do
            field :env_authorizable
        end
    end
  
end
