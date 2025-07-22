# == Schema Information
#
# Table name: subject_types
#
#  id         :bigint           not null, primary key
#  code       :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class SubjectType < ApplicationRecord
  
  #ASSOCIATIONS:
  has_many :subjects
  # HISTORY:
	has_paper_trail on: [:create, :destroy, :update]

	before_create :paper_trail_create
	before_destroy :paper_trail_destroy
	before_update :paper_trail_update

  # VALIDATIONS:
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true
  validates_format_of :code, with: /\A[a-z]+\z/i

  scope :obligatoria, -> {where("lower(name) = 'obligatoria'").first}
  

  # RAILS_ADMIN:
  rails_admin do
    visible false
    list do
      fields :code, :name
    end
    edit do
      field :code do
        html_attributes do
          {onInput: "$(this).val($(this).val().toUpperCase().replace(/[^A-Z]/g,'').substr(0, 2))"}
        end
        help 'Hasta 2 letra permitidas'
      end
      field :name do
        html_attributes do
          {onInput: "$(this).val($(this).val().toUpperCase().replace(/[^A-Z]/g,''))"}
        end
      end
    end

    update do
      field :code do
        read_only true
      end
      field :name do
        html_attributes do
          {onInput: "$(this).val($(this).val().toUpperCase().replace(/[^A-Z]/g,''))"}
        end
      end
    end
  end

  def desc_pluralize
    "#{self.name&.downcase&.pluralize&.titleize} (#{self.code})"
  end

  private

    def paper_trail_update
      changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} actualizada en #{changed_fields.to_sentence}"
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrada!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Tipo de Asignatura eliminada!"
    end
end
