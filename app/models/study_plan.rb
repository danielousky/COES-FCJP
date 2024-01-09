class StudyPlan < ApplicationRecord
  # SCHEMA:
  # t.string "code"
  # t.string "name"
  # t.bigint "school_id", null: false 
  
  
  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :school
  # accepts_nested_attributes_for :school

  has_many :grades, dependent: :destroy
  has_many :requirement_by_subject_types, dependent: :destroy
  accepts_nested_attributes_for :requirement_by_subject_types, allow_destroy: true  

  # VALIDATIONS:
  validates :code, presence: true
  validates :name, presence: true
  validates :requirement_by_subject_types, presence: true
  validates :school, presence: true

  # CALLBACKS:
  after_initialize :set_unique_school
  before_save :clean_values

  # HOOKS:
  def clean_values
    self.name.delete! '^0-9|^A-Za-z|áÁÄäËëÉéÍÏïíÓóÖöÚúÜüñÑ '
    self.name.strip!
    self.code.delete! '^0-9|^A-Za-z|áÁÄäËëÉéÍÏïíÓóÖöÚúÜüñÑ'
    self.code.strip!
    self.name.upcase!
    self.code.upcase!
  end

  # FUNTIONS:
  def desc_with_school
    "#{school.short_name} - #{name}"
  end

  def desc
    "(#{code}) #{name}"
  end

  # def desc_credits
  #   "(Créditos Requeridos) #{mandatory_credits}"
  # end

  rails_admin do
    navigation_label 'Config General'
    navigation_icon 'fa-solid fa-award'
    weight -2

    show do
      fields :school, :code, :name, :requirement_by_subject_types
    end

    list do
      field :school do

        pretty_value do
          bindings[:object].school&.short_name
        end
      end
      fields :code, :name, :requirement_by_subject_types
    end

    export do
      fields :code, :name, :requirement_by_subject_types
    end

    edit do
      field :school do
        inline_add false
        inline_edit false 
      end
      field :code do 
        html_attributes do
          {:length => 8, :size => 8, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^a-zA-Z0-9\u00f1\u00d1 ]/g,''))"}
        end
      end
      field :name do
        html_attributes do
          {:onInput => "$(this).val($(this).val().toUpperCase())"}
        end        
      end
      field :requirement_by_subject_types
    end

  end

  def set_unique_school
    self.school_id = School.first.id if School.count.eql? 1
  end

  private
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
      self.paper_trail_event = "¡Plan de Estudio eliminado!"
    end


end
