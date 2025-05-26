# == Schema Information
#
# Table name: partial_qualifications
#
#  id                 :bigint           not null, primary key
#  partial            :integer          default("primer_lapso"), not null
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
  has_one :section, through: :academic_record
  has_one :course, through: :section
  has_one :subject, through: :course
  has_one :area, through: :subject

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

  def get_percent_value
    if primer_lapso? or segundo_lapso?
      30
    else
      40
    end
  end


  def get_qualification_percent
    # percent.to_f.percent_of(self.value.to_f)
		# porcen1 = (p1*nota1)/100;
		# porcen1 =  Math.round(porcen1 * 10) / 10;
    
    # percent = (get_percent_value*self.value)/100
    # (percent*10).round(0)/10
    percent_partial = self.get_percent_value

    (percent_partial*self.value)/100
  end

  def totalize_qualification
    require 'numeric'
    if self.academic_record.is_totality_partial?
      total = 0
      self.academic_record.partial_qualifications.each do |pq|

        # porcen1 = (p1*nota1)/100;
        # porcen1 =  Math.round(porcen1 * 10) / 10;
        # porcen2 = (p2*nota2)/100;
        # porcen2 =  Math.round(porcen2 * 10) / 10;
        # porcen3 = (p3*nota3)/100;
        # porcen3 =  Math.round(porcen3 * 10) / 10;
        percent = pq.get_qualification_percent

        total += percent #(pq.value).percent_of(get_percent_value)
      end
      total = total.round(0)
      self.academic_record.qualifications.destroy_all
      self.academic_record.qualifications.create!(type_q: :final, value: total, definitive: true)
    end
  end

end
