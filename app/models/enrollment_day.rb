# == Schema Information
#
# Table name: enrollment_days
#
#  id                    :bigint           not null, primary key
#  by_before_process     :boolean          default(TRUE), not null
#  max_grades            :integer
#  slot_duration_minutes :integer
#  start                 :datetime
#  total_duration_hours  :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  academic_process_id   :bigint           not null
#
# Indexes
#
#  index_enrollment_days_on_academic_process_id  (academic_process_id)
#
# Foreign Keys
#
#  fk_rails_...  (academic_process_id => academic_processes.id)
#
class EnrollmentDay < ApplicationRecord

  #RELATIONSHIPS:
  belongs_to :academic_process
  has_one :school, through: :academic_process 
  has_one :period, through: :academic_process 
  
  # VALIDACIONES
  validates :academic_process_id, presence: true
  validates :start, presence: true
  validates :total_duration_hours, presence: true
  validates :max_grades, presence: true
  validates :slot_duration_minutes, presence: true

  validates_with UniqEnrollmentDayValidator, field_name: false, if: :new_record?

  #CALLBACK
  after_destroy :clean_grades_with_appointment_time

  #SCOPE
  scope :current_process, -> (academic_process_id) { of_today.where(academic_process_id: academic_process_id)}

  scope :of_today, -> {where(start: Time.zone.now.all_day)}
  
  def active_now?
    Time.zone.now > self.start and Time.zone.now < self.start+total_duration_hours.hours
  end

  #MÉTODOS

  #CSV:
  def name_to_file
    "#{academic_process.school.code}_#{academic_process.process_name}_#{start.strftime('%Y%m%d')}_#{self.id}"
  end






  
  def own_grades_to_csv

    CSV.generate do |csv|
      csv << ['Cédula', 'Apellido y Nombre', 'Correo', 'Sede', 'Desde', 'Hasta', 'Eficiencia', 'Promedio', 'Ponderado']
      own_grades_sort_by_appointment.each do |grade|
        user = grade.user
        if self.by_before_process
          academic_process = self.academic_process.process_before
          obj = grade.enroll_academic_processes.where(academic_process_id: academic_process.id).first if academic_process.present?
          obj ||= grade
        else
          obj = grade
        end
        
        csv << [user.ci, user.reverse_name, user.email, grade.student.sede, grade.appointment_from, grade.appointment_to, obj.efficiency_desc, obj.simple_average_desc, obj.weighted_average_desc]
      end
    end
  end

  def total_timeslots #total_franjas
    (slot_duration_minutes.eql? 0) ? 0 : (self.total_duration_hours/self.slot_duration_minutes.to_f*60).to_i
  end

  def grades_by_timeslot #grado_x_franja 
    if self.total_timeslots > max_grades 
      return max_grades 
    else
      (self.total_timeslots > 0) ? (max_grades/total_timeslots) : 0
    end
  end

  def mod_to_grades
    (total_timeslots.eql? 0) ? 0 : max_grades%total_timeslots
  end


  def own_grades
    self.school.grades.with_day_enroll_eql_to(self.start)
  end

  def own_grades_count
    self.own_grades.count
  end

  def own_grades_sort_by_appointment
    # self.own_grades.order([appointment_time: :asc, duration_slot_time: :asc, efficiency: :desc, simple_average: :desc, weighted_average: :desc])
    
    self.own_grades.joins(:enroll_academic_processes).order([appointment_time: :asc, duration_slot_time: :asc, 'enroll_academic_processes.efficiency': :desc, 'enroll_academic_processes.simple_average': :desc, 'enroll_academic_processes.weighted_average': :desc]).uniq
  end

  def own_grades_sort_by_numbers
    self.own_grades.order([efficiency: :desc, simple_average: :desc, weighted_average: :desc])
  end

  def clean_grades_with_appointment_time
    self.own_grades.update_all(appointment_time: nil, duration_slot_time: nil)
  end

end
