# == Schema Information
#
# Table name: payment_reports
#
#  id                        :bigint           not null, primary key
#  amount                    :float
#  owner_account_ci          :string
#  owner_account_name        :string
#  payable_type              :string
#  status                    :integer          default("Pendiente"), not null
#  transaction_date          :date
#  transaction_type          :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  origin_bank_id            :bigint           not null
#  payable_id                :bigint
#  receiving_bank_account_id :bigint
#  school_id                 :bigint
#  transaction_id            :string
#  user_id                   :bigint
#
# Indexes
#
#  index_payment_reports_on_origin_bank_id             (origin_bank_id)
#  index_payment_reports_on_payable                    (payable_type,payable_id)
#  index_payment_reports_on_receiving_bank_account_id  (receiving_bank_account_id)
#  index_payment_reports_on_school_id                  (school_id)
#  index_payment_reports_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (origin_bank_id => banks.id)
#  fk_rails_...  (receiving_bank_account_id => bank_accounts.id) ON DELETE => nullify ON UPDATE => cascade
#  fk_rails_...  (school_id => schools.id)
#  fk_rails_...  (user_id => users.id)
#
class PaymentReport < ApplicationRecord

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update


  # ASSOCIATIONS:
  belongs_to :origin_bank, class_name: 'Bank', foreign_key: 'origin_bank_id'
  belongs_to :payable, polymorphic: true
  belongs_to :school
  belongs_to :user
  # Atención: Esta es la mejor opción pero es posible que no funcione por el polimorfismo
  # has_one :student, through: :payable
  # has_one :user, through: :student
  belongs_to :receiving_bank_account, class_name: 'BankAccount'

  has_one_attached :voucher do |attachable|
    attachable.variant :thumb, resize_to_limit: [100,100]
  end

  scope :todos, -> {where('0 = 0')}
  scope :pagos_escuela, -> {where(payable_type: 'Grade')}  
  scope :pagos_inscripcion, -> {where(payable_type: 'EnrollAcademicProcess')}  

  scope :custom_search, -> (keyword) {joins_enroll_academic_process.joins("INNER JOIN academic_processes ON enroll_academic_processes.academic_process_id = academic_processes.id").where("academic_processes.name ILIKE '%#{keyword}%'") }  


  attr_accessor :remove_voucher
  after_save { voucher.purge if remove_voucher.eql? '1' }   

  before_validation :set_payable_values

  def set_payable_values
    self.school_id = self.school_by_payable.id
    self.user_id = self.user_by_payable.id
  end

  # VALIDATIONS:
  # validates :payable_id, presence: true
  # validates :payable_type, presence: true
  validates :payable, presence: true
  validates :amount, presence: true
  validates :transaction_id, presence: true
  validates :transaction_type, presence: true
  validates :transaction_date, presence: true
  validates :origin_bank, presence: true
  validates :receiving_bank_account, presence: true
  # validates :voucher, presence: true

  # Enum:
  enum transaction_type: {transferencia: 0, deposito: 1}
  enum status: [:Pendiente, :Validado, :Invalidado]

  # SPECIALS FUNCTIONS OF POLYMORPHIC:
  def student_by_payable
    payable&.student
  end

  def school_by_payable
    payable&.school
  end  

  def user_by_payable
    student_by_payable&.user
  end

  def academic_process
    payable&.academic_process
  end

  # BASIC FUNCTIONS:
  def name
    "#{transaction_id} - #{amount_to_bs}"
  end

  def amount_to_bs
    ActionController::Base.helpers.number_to_currency(self.amount, unit: 'Bs.', separator: ",", delimiter: ".")
  end
  
  def label_status readonly=false
    case status
    when "Invalidado"
      ApplicationController.helpers.label_status("bg-danger", self.status&.titleize)
    when "Validado"
      ApplicationController.helpers.label_status("bg-success", self.status&.titleize)
    else
      if readonly
        ApplicationController.helpers.label_status("bg-warning mx-2", self.status&.titleize)
      else
        aux = ApplicationController.helpers.label_status("bg-warning mx-2", self.status&.titleize)
        aux += "<a href='/payment_reports/#{self.id}/quick_validation?payment_report[status]=Validado' class='label label-sm bg-success' data-bs-placement='right' data-bs-original-title='Validación rápida' rel='tooltip' data-bs-toggle='tooltip'><i class='fa fa-check'></i></a>".html_safe
        aux.html_safe
      end
    end    
  end

  def label_show_modal label_id, label_title 

    "<button class='btn btn-sm btn-success mx-2' data-bs-target='##{label_id}' data-bs-toggle='modal' type='button' aria-label='#{label_title}' data-bs-original-title='#{label_title}'>
    <i class='fa fa-receipt'></i>
    </button>"

  end

  # OTHERS FUNCTIONS:


  rails_admin do
    navigation_label 'Administrativa'
    navigation_icon 'fa-solid fa-cash-register'

    list do
      # fields :amount, :transaction_id, :transaction_type, :transaction_date, :origin_bank, :receiving_bank_account, :owner_account_ci, :owner_account_name

      search_by :custom_search
      scopes [:todos, :pagos_escuela, :pagos_inscripcion, :Pendiente, :Validado, :Invalidado]
      field :id do
        sticky true
      end

      field :created_at do
        sticky true
      end
      field :status do
        sticky true
        pretty_value do
          bindings[:object].label_status
        end
      end      

      field :amount
      field :academic_process do
        label 'Período'
        formatted_value do
          bindings[:object].academic_process&.name if bindings[:object].payable_type.eql? 'EnrollAcademicProcess'
        end
      end
      field :student do
        pretty_value do
          if bindings[:view]._current_user&.admin&.authorized_read? 'Student'
            "<a href='/admin/student/#{bindings[:object].user_id}'>#{bindings[:object].user&.ci_fullname}</a>".html_safe
          else
            bindings[:object].user&.ci_fullname
          end
        end
      end
      # field :payable_name do
      #   label 'Descripción'
      #   formatted_value do
      #     bindings[:object].payable.name
      #   end
      # end
      
      fields :transaction_id, :transaction_type, :transaction_date, :origin_bank, :receiving_bank_account     

      field :voucher do
        filterable false

        formatted_value do
          if (bindings[:object].voucher&.attached? and bindings[:object].voucher&.representable?)
            bindings[:view].render(partial: "layouts/set_image", locals: {image: bindings[:object].voucher, size: '30x30'})
          else
            false
          end
        end
      end

      fields :owner_account_ci, :owner_account_name
    end

    show do
      fields :id, :created_at, :amount, :status, :transaction_id, :transaction_type, :transaction_date, :origin_bank, :receiving_bank_account, :voucher, :owner_account_ci, :owner_account_name
    end

    edit do
      field :amount
      field :transaction_id do
        html_attributes do
          {:length => 20, :size => 20, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^0-9]/g,''))"}
        end
      end
      field :status
      field :payable do
        label 'Entidad a Pagar'
      end
      fields :transaction_type, :transaction_date
      field :origin_bank do
        inline_edit false
        inline_add false
      end
      field :receiving_bank_account do
        inline_edit false
        inline_add false
      end
      fields :voucher, :owner_account_ci, :owner_account_name
    end

    export do
      fields :id, :created_at, :amount, :transaction_id, :transaction_type, :transaction_date, :origin_bank, :origin_bank, :owner_account_ci, :owner_account_name
      field :payable_type do
        label 'Tipo'
      end
      field :payable_id do
        label 'Id'
      end

      field :payable_name do
        label 'Descripción'
        formatted_value do
          bindings[:object].payable.name
        end
      end

      field :user_name do
        label 'Nombre Usuario'
        formatted_value do
          bindings[:object].student.user.first_name
        end
      end

      field :user_last_name do
        label 'Apellido Usuario'
        formatted_value do
          bindings[:object].student.user.last_name
        end
      end
      
      field :user_ci do
        label 'Ci Usuario'
        formatted_value do
          bindings[:object].student.user.ci
        end
      end
    end
  end  

  private


    def paper_trail_update
      changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      if self.status_changed?
        self.paper_trail_event = "¡#{object} #{self.status}!"
      else
        self.paper_trail_event = "¡#{object} actualizado!"
        # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      end      
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Reporte de Pago eliminado!"
    end

end
