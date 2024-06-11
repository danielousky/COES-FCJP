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
  
  belongs_to :academic_record
  # accepts_nested_attributes_for :academic_record

  has_one :enroll_academic_process, through: :academic_record
  has_one :grade, through: :enroll_academic_process


  scope :by_type_q, -> (type_q) {where(type_q: type_q)}
  scope :post, -> {where(type_q: [:diferido, :reparacion])}

  scope :definitive, -> {where(definitive: true)}

  enum type_q: [:final, :diferido, :reparacion]

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

  def approved?
    if is_valid_numeric_value?
      value >= 10
    else
      false
    end
  end

  def repproved?
    if is_valid_numeric_value?
      value < 10
    else
      false
    end
  end

  def conv_type
    type = I18n.t(self.type_q)
    type = type[1]

    modality_process = academic_record.academic_process.modality[0]
    modality_process ||= 'A'

    "#{type.upcase}#{modality_process.upcase}#{academic_record.period.period_type.code.last}"
  end  


  def desc_conv
    I18n.t(self.type_q)
    # OJO
    # if self.final? and (self.academic_record.absolute_pi_or_rt?)
    #   I18n.t(self.academic_record.status)
    # else
      
    # end
  end

  def is_valid_numeric_value?
    !value.blank? and (value.is_a? Integer or value.is_a? Float)
  end

  def value_to_02i
    is_valid_numeric_value? ? sprintf("%02i", value) : nil
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
end
