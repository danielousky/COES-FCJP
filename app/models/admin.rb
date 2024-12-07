# == Schema Information
#
# Table name: admins
#
#  env_authorizable_type :string           default("Faculty")
#  role                  :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  env_authorizable_id   :bigint
#  profile_id            :bigint
#  user_id               :bigint           not null, primary key
#
# Indexes
#
#  index_admins_on_env_authorizable  (env_authorizable_type,env_authorizable_id)
#  index_admins_on_profile_id        (profile_id)
#  index_admins_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Admin < ApplicationRecord
  include Userable

  # ENUMERIZE:
  # enum role: [:desarrollador, :jefe_control_estudio, :asistente]
  enum role: {desarrollador: 0, jefe_control_estudio: 1, asistente: 3}
  

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :user
  # accepts_nested_attributes_for :user
  
  
  belongs_to :profile, optional: true

  has_many :authorizeds
  
  has_many :env_auths, dependent: :destroy
  accepts_nested_attributes_for :env_auths, allow_destroy: true

  before_save :set_role


  # VALIDATIONS:
  validates :user, presence: true, uniqueness: true
  # validates :env_authorizable, presence: true
  validates :role, presence: true

  validates :env_auths, presence: true
  # validates :env_authorizable_type, presence: true

  # SCOPES:
  scope :find_by_user_ci, -> (ci) {joins(:user).where('users.ci': ci).first}

  scope :custom_search, -> (keyword) { joins(:user).where("users.ci ILIKE '%#{keyword}%' OR users.email ILIKE '%#{keyword}%' OR users.first_name ILIKE '%#{keyword}%' OR users.last_name ILIKE '%#{keyword}%'") }


  def yo?
    self.user.email.eql? 'moros.daniel@gmail.com' and self.user_id.eql? 1
  end

  # CALLBACKS:
  after_destroy :check_user_for_destroy
  
  # HOOKS:
  def check_user_for_destroy
    user_aux = User.find self.user_id
    user_aux.delete if user_aux.without_rol?
  end 

  # FUNCTIONS:

  def is_departament?
    env_auths&.pluck(:env_authorizable_type).uniq.first.to_s.eql? 'Departament'
  end

  def departaments
    if is_departament?
      ids = env_auths.pluck(:env_authorizable_id)
    else
      ids = schools_auh.joins(:departaments).pluck(:"departaments.id")
    end
    Departament.where(id: ids)
  end

  def schools_auh
    if (desarrollador?)
      School.all
    elsif env_auths.any?   
      if env_auths.pluck(:env_authorizable_type).uniq.first.to_s.eql? 'School'
        ids = env_auths.pluck(:env_authorizable_id)
        School.where(id: ids)
      elsif env_auths.pluck(:env_authorizable_type).uniq.first.to_s.eql? 'Departament'
        ids = env_auths.pluck(:env_authorizable_id)
        school_ids = Departament.where(id: ids).pluck(:school_id)
        School.where(id: school_ids)
      end
    else
      nil
    end
  end
  def authorized_to action_name, clazz
    case action_name
    when 'create'
      authorized_create? clazz
    when 'manage'
      authorized_manage? clazz
    when 'delete'
      authorized_delete? clazz
    when 'update'  
      authorized_update? clazz
    else
      false
    end
  end

  def authorized_create? clazz
    if yo? or desarrollador? or jefe_control_estudio?
      return true
    else
      
      if authorizable = Authorizable.where(klazz: clazz).first
        if authorized = authorizeds.where(authorizable_id: authorizable.id).first
          return authorized.can_create?
        else
          return false
        end
      else
        return false
      end
    end
  end

  def authorized_manage? clazz
    if yo? or desarrollador? or jefe_control_estudio?
      return true
    else
      
      if authorizable = Authorizable.where(klazz: clazz).first
        if authorized = authorizeds.where(authorizable_id: authorizable.id).first
          return authorized.can_manage?
        else
          return false
        end
      else
        return false
      end
    end
  end
 
  def authorized_delete? clazz
    if yo? or desarrollador? or jefe_control_estudio?
      return true
    else
      
      if authorizable = Authorizable.where(klazz: clazz).first
        if authorized = authorizeds.where(authorizable_id: authorizable.id).first
          return authorized.can_delete?
        else
          return false
        end
      else
        return false
      end
    end
  end

  def authorized_update? clazz
    if yo? or desarrollador? or jefe_control_estudio?
      return true
    else
      
      if authorizable = Authorizable.where(klazz: clazz).first
        if authorized = authorizeds.where(authorizable_id: authorizable.id).first
          return authorized.can_update?
        else
          return false
        end
      else
        return false
      end
    end
  end

  def authorized_read? clazz
    if yo? or desarrollador? or jefe_control_estudio?
      return true
    else
      
      if authorizable = Authorizable.where(klazz: clazz).first
        if authorized = authorizeds.where(authorizable_id: authorizable.id).first
          return authorized.can_read?
        else
          return false
        end
      else
        return false
      end
    end
  end


  rails_admin do
    navigation_label 'Gestión de Usuarios'
    navigation_icon 'fa-regular fa-user-tie'

    show do
      field :user 
      # field :role do
      #   pretty_value do
      #     value.titleize
      #   end
      # end
      field :pare do
        label 'PARE (Procesos de Acceso Restringido)'
        formatted_value do
          unless bindings[:object].jefe_control_estudio? or bindings[:object].desarrollador?

            bindings[:view].render(partial: 'authorizeds/form', locals: {user: bindings[:object].user})
          end
        end
      end

      field :env_auths

      # field :env_authorizable 
      # field :created_at
    end

    list do
      checkboxes false
      search_by :custom_search
      field :user do
        sticky true
        pretty_value do
          value.description
        end
      end
      field :role do
        visible do
          user = bindings[:view]._current_user
          (user and user.admin and user.admin.desarrollador? )
        end
        pretty_value do
          value.titleize
        end        
      end
      field :env_auths
      # field :created_at
      field :link_to_reset_password do
        label 'Opciones'
        visible do
          user = bindings[:view]._current_user
          user&.admin&.authorized_manage? 'Admin'
        end
      end
    end

    edit do
      field :user 
      field :role do
        partial 'admin/custom_role_field'
      end
        # visible do
        #   user = bindings[:view]._current_user
        #   (user and user.admin and user.admin.yo? )
        # end
      # end

      # field :env_authorizable
      # field :authorizeds

      # field :role do
      #   html_attributes do
      #     {:onChange => "alert($(this).val())"}

      #   end
      # end

      field :env_auths do
        active true
      # field :env_auths do
      #   partial 'env_auth/custom_env_auth_field'
      # end
        pretty_value do
          value.short_name
        end
      end
    end

    export do
      field :role
      field :user
      field :env_auths
    end
  end

  
  private

    def set_role
      self.role = :asistente if self.role.nil?
    end

    def paper_trail_update
      # changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      self.paper_trail_event = "¡#{object} actualizado!"
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Administrador eliminado!"
    end
end
