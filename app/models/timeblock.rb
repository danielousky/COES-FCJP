# == Schema Information
#
# Table name: timeblocks
#
#  id           :bigint           not null, primary key
#  classroom    :string
#  day          :integer          default("Lunes")
#  end_time     :time             default(Sat, 01 Jan 2000 05:00:00.000000000 -04 -04:00)
#  modality     :integer          default("Presencial")
#  start_time   :time             default(Sat, 01 Jan 2000 03:00:00.000000000 -04 -04:00)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  teacher_id   :bigint
#  timetable_id :bigint           not null
#
# Indexes
#
#  index_timeblocks_on_teacher_id                        (teacher_id)
#  index_timeblocks_on_timetable_and_day_and_end_time    (timetable_id,day,end_time) UNIQUE
#  index_timeblocks_on_timetable_and_day_and_start_time  (timetable_id,day,start_time) UNIQUE
#  index_timeblocks_on_timetable_id                      (timetable_id)
#
# Foreign Keys
#
#  fk_rails_...  (timetable_id => timetables.id)
#
class Timeblock < ApplicationRecord
  belongs_to :teacher, optional: true
  belongs_to :timetable
  has_one :section, through: :timetable

  ALLOWED_START= 6
  ALLWOED_END= 21

  enum modality: { Presencial: 0, Virtual: 1 }
  enum day: {Lunes: 0, Martes: 1, Miercoles: 2, Jueves: 3, Viernes: 4, Sabado: 5}

  validates :day, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :start_time_must_be_at_least_thirty_minutes_before_end_time

  validate :start_and_end_time_within_allowed_range

  def start_and_end_time_within_allowed_range
    if start_time.present? && (start_time.hour < ALLOWED_START || start_time.hour > ALLWOED_END)
      errors.add(:start_time, "debe estar entre las 6:00am y las 9:00pm", field_name: false)
    end
    if end_time.present? && (end_time.hour < ALLOWED_START || end_time.hour > ALLWOED_END)
      errors.add(:end_time, "debe estar entre las 6:00am y las 9:00pm", field_name: false)
    end
  end

  def start_time_must_be_at_least_thirty_minutes_before_end_time
    return if start_time.blank? || end_time.blank?
    if (end_time - start_time) < 30.minutes
      errors.add(:start_time, :too_close_to_end)
    end
  end
  validates :modality, presence: true
  
  validates_uniqueness_of :timetable_id, scope: [:day, :start_time], message: 'Ya existe un bloque horario con una hora de entrada igual para el horario.', field_name: false
  validates_uniqueness_of :timetable_id, scope: [:day, :end_time], message: 'Ya existe un bloque horario con una hora de salida igual para el horario.', field_name: false

  after_save :update_timetable_name
  
  # FUNCITONS
  def short_name
    if day and start_time and end_time      
      start_format = (start_time.to_a[1]&.to_i.eql? 0) ? "%I%P" : "%I:%M%P"
      end_format = (end_time.to_a[1]&.to_i.eql? 0) ? "%I%P" : "%I:%M%P"
      aux = "#{day[0..1]} #{I18n.l(start_time, format: start_format)} #{I18n.l(end_time, format: end_format)}" 
      aux += "| #{classroom}" unless classroom.blank?
      return aux
    end

  end

  def select_de_modalidad
    "#{ApplicationController.helpers.select_tag 'bloquehorarios[modalidad][]', ApplicationController.helpers.options_for_select(Timeblock.modalities.keys{|mo| mo.titleize}, self.modality) , class: ' form-control form-control-sm'}"
  end

  def description_section_to_teacher
    aux =  teacher ? "#{teacher.user_description} <br>" : ""
    aux += " #{timetable.description_section} : #{timetable.section&.subject&.desc}"
    return aux
  end

  def name
    aux = "#{day}: #{start_time_to_schedule} a #{end_time_to_schedule} (#{virtual_letter})"
    aux += " | #{classroom}" unless classroom.blank?
    return aux
  end
  # FUNCTIONS FOR SCHEDULES
  def start_time_to_schedule
    start_time.strftime("%I:%M%P")
  end

  def end_time_to_schedule
    end_time.strftime("%I:%M%P")
  end

  def title
    "#{start_time.strftime("%H:%M")} - #{end_time.strftime("%H:%M")}"
  end
  def virtual_letter
    modality[0..5].titleize
  end
  def day_to_letter
    if day.eql? 'Miércoles'
      'X'
    else
      day.first.upcase
    end
  end

  def desc_teacher_busy
    teacher ? "#{teacher.user&.first_name} está ocupad#{teacher.user.genero} en éste horario con #{timetable.section&.number} de #{timetable.section&.subject&.code}" : ""
  end


  def same_block? timetable_id
    aux = Timetable.find timetable_id

    bloquesOrigen = aux.timeblocks.map{|bh| bh.day_and_start}

    bloquesOrigen.include? day_and_start
  end

  def day_and_start
    "#{day} #{start_desc}"
  end
  def start_desc
    Timeblock.hour_description start_time
  end

  def end_desc
    Timeblock.hour_description end_time
  end

  def self.hour_description time
    if time
      if I18n.l(time, format: '%M').eql? '00'
        return I18n.l(time, format: '%I%P')
      else
        return I18n.l(time, format: '%I%M%P')
      end
    else
      return ""
    end
  end

  rails_admin do
    visible false
    list do
      field :day
      field :start_time do
        formatted_value do
          value ? I18n.l(value, format: '%H:%M') : ''
        end
      end
      field :end_time do
        formatted_value do
          value ? I18n.l(value, format: '%H:%M') : ''
        end
      end
      field :modality
      field :timetable
      field :teacher do
        formatted_value do
          value ? value.user_description : ''
        end
      end
    end
    edit do
      field :day
      field :start_time do
        html_attributes do
          { step: '900' } # 15 minutes step
        end
      end

      field :end_time
      field :modality
      field :teacher do
        # associated_collection_scope do
        #   Proc.new { |scope|
        #     scope = scope.joins(:section).where(timetables: {id: bindings[:object].timetable_id})
        #     scope = scope.limit(10)
        #   }
        # end
        inline_edit false
        inline_add false        
      end
      field :classroom do
        html_attributes do
          {:onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9| ]/g,''))"}
        end        
      end
    end
  end

  private

  def update_timetable_name
    timetable.update(name: timetable.description) if timetable.present?
  end

end
