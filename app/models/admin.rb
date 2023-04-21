class Admin < ApplicationRecord
  # SCHEMA:
  # t.bigint "user_id", null: false
  # t.integer "role"
  # t.string "env_authorizable_type", default: "Faculty"
  # t.bigint "env_authorizable_id"

  # ENUMERIZE:
  enum role: [:desarrollador, :jefe_control_estudio, :asistente]

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :user
  # accepts_nested_attributes_for :user
  
  belongs_to :env_authorizable, polymorphic: true, optional: true
  belongs_to :profile, optional: true

  has_many :authorizeds

  before_save :set_role


  # VALIDATIONS:
  validates :user, presence: true, uniqueness: true
  # validates :env_authorizable, presence: true
  # validates :user, presence: true
  # validates :role, presence: true

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
          bindings[:view].render(partial: 'authorizeds/form', locals: {user: bindings[:object].user})
        end
      end


      # field :env_authorizable 
      # field :created_at
    end

    list do
      search_by :custom_search
      field :user
      field :role do
        visible do
          user = bindings[:view]._current_user
          (user and user.admin and user.admin.yo? )
        end
      end
      # field :env_authorizable
      # field :created_at
    end

    edit do
      field :user 
      field :role do
        visible do
          user = bindings[:view]._current_user
          (user and user.admin and user.admin.yo? )
        end
      end

      # field :env_authorizable
      # field :authorizeds

      # field :role do
      #   html_attributes do
      #     {:onChange => "alert($(this).val())"}

      #   end
      # end
    end

    export do
      field :role
      field :user
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
