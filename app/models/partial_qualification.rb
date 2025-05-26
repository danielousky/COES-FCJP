# == Schema Information
#
# Table name: partial_qualifications
#
#  id                 :bigint           not null, primary key
#  partial            :integer          default("primera"), not null
#  value              :decimal(4, 2)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  academic_record_id :bigint           not null
#
# Indexes
#
#  index_partial_qualifications_on_academic_record_id  (academic_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (academic_record_id => academic_records.id)
#
class PartialQualification < ApplicationRecord
  include Qualifying
  # ASSOCIATIONS:
  belongs_to :academic_record

  has_paper_trail on: [:create, :destroy, :update]
  
  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # VALIDATIONS:
  validates :academic_record, presence: true
  validates :value, presence: true, numericality: { in: 0..20, message: 'El número debe estar entre 0 y 20' }
  validates :partial, presence: true
  validates_uniqueness_of :partial, scope: :academic_record_id, message: 'Calificación parcial duplicada'


  
  #ENUMS:
  # enum partial: [:primera, :segunda, :tercera]
  enum partial: {primer_lapso: 1, segundo_lapso: 2, tercer_lapso: 3}
  
  #CALLBACKS:
  after_save :totalize_qualification

  def totalize_qualification
    require 'numeric'
    if self.academic_record.is_totality_partial?
      total = 0
      self.academic_record.partial_qualifications.each do |pq|
        total += (pq.value).percent_of(33)
      end
      total = total.round(0)
      self.academic_record.qualifications.destroy_all
      self.academic_record.qualifications.create!(type_q: :final, value: total, definitive: true)
    end
  end

  private

  def paper_trail_update
    changed_fields = self.changes.keys - ['created_at', 'updated_at']
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
  end  

  def paper_trail_create
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Completada inscripción en Curso!"
  end  

  def paper_trail_destroy
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Registro Académico eliminado!"
  end  

end
