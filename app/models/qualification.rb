# == Schema Information
#
# Table name: qualifications
#
#  id                 :bigint           not null, primary key
#  definitive         :boolean          default(TRUE), not null
#  type_q             :integer          default("final"), not null
#  value              :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  academic_record_id :bigint           not null
#
# Indexes
#
#  index_qualifications_on_academic_record_id  (academic_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (academic_record_id => academic_records.id)
#
class Qualification < ApplicationRecord

  has_paper_trail on: [:create, :destroy, :update]

  # CALLBACK
  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  include Qualifying
  
  belongs_to :academic_record
  # accepts_nested_attributes_for :academic_record

  has_one :enroll_academic_process, through: :academic_record
  has_one :grade, through: :enroll_academic_process
  has_one :section, through: :academic_record


  scope :by_type_q, -> (type_q) {where(type_q: type_q)}
  scope :post, -> {where(type_q: [:diferido, :reparacion])}

  scope :definitive, -> {where(definitive: true)}

  default_scope {order(:type_q)}

  enum type_q: {final: 0, diferido: 1, reparacion: 2}

  validates :academic_record, presence: true
  validates :value, presence: true, numericality: { only_integer: true, in: 0..20 }
  validates :type_q, presence: true
  validates_uniqueness_of :academic_record, scope: [:type_q], message: 'Calificación ya existente', field_name: false

  after_save :update_academic_record_status
  after_destroy :update_academic_record_status

  def name
    "#{type_q.titleize} #{value}" if (type_q and value)
  end
  def num_to_s
    (academic_record.num_to_s value.to_i) if value
  end

  def update_academic_record_status    
    definitive_q_value = self.academic_record.definitive_q_value
    if definitive_q_value and !self.academic_record.pi?
      status = (definitive_q_value >= 10) ? :aprobado : :aplazado
      self.academic_record.update(status: status)
    end
    update_status
  end
  def conv_type
    type = I18n.t(self.type_q)
    type = type[1]

    modality_process = academic_record.academic_process.modality[0]
    modality_process ||= 'A'

    "#{type.upcase}#{modality_process.upcase}#{academic_record.period.period_type.code.last}"
  end  

  def status_of_q
    # Attention: This Status do reference to the Qualification directy and not to AcademicRecord. 
    # For Example: when have two qualifications and one is 'aplazado' and the other is 'aprovado' 
    
    if value and value > 10
      I18n.t('activerecord.models.academic_record.status.A')
    else
      I18n.t('activerecord.models.academic_record.status.AP')
    end
  end

  def cal_alfa
    I18n.t('activerecord.models.academic_record.status.'+status_of_q)
  end


  def desc_conv

    # OJO: Hay un problema con el estado, no puede ser el mismo de la definitiva (academic_record) ya que es A y debe ser AP
    
    if section.any_equivalencia?
      I18n.t("activerecord.scopes.section."+self.section.modality)
    else
      I18n.t(self.type_q)
    end
    # OJO
    # if self.final? and (self.academic_record.absolute_pi_or_rt?)
    #   I18n.t(self.academic_record.status)
    # else
      
    # end
  end

  def value_to_acta
    academic_record&.pi? ? 'PI' : value_to_02i
  end

  rails_admin do
    edit do
      fields :value, :type_q
    end
    export do
      field :value, :string
      field :type_q
    end
  end

  private

  def update_status

    if self.diferido? or self.reparacion?
      self.academic_record.qualifications.final.first&.update(definitive: false)
    end

    eap = self.enroll_academic_process
    eap.update(permanence_status: eap.get_regulation) if enroll_academic_process&.finished?
    
    eap.update(efficiency: eap.calculate_efficiency, simple_average: eap.calculate_average, weighted_average: eap.calculate_weighted_average)    

    grado = self.grade
    grado.update(efficiency: grado.calculate_efficiency, simple_average: grado.calculate_average, weighted_average: grado.calculate_weighted_average)
  end

  def paper_trail_update
    changed_fields = self.changes.keys - ['created_at', 'updated_at']
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    changed_fields.each do |field|
      old_value, new_value = self.changes[field]
      self.paper_trail_event = "¡#{object} cambió #{field} de #{old_value.inspect} a #{new_value.inspect}!"
    end
  end  

  def paper_trail_create
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Calificada, #{type_q}: #{self.value} #{'(definitiva)' if definitive}!"
  end  

  def paper_trail_destroy
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Registro Académico eliminado!"
  end  

end
