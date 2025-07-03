# == Schema Information
#
# Table name: addresses
#
#  id           :bigint           not null, primary key
#  city         :string
#  house_name   :string
#  house_type   :integer
#  municipality :string
#  sector       :string
#  state        :string
#  street       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  student_id   :bigint           not null
#
# Indexes
#
#  index_addresses_on_student_id  (student_id)
#
# Foreign Keys
#
#  fk_rails_...  (student_id => students.user_id) ON DELETE => cascade ON UPDATE => cascade
#
class Address < ApplicationRecord

  # ENUMERIZE:
  enum house_type: [:casa, :quinta, :apartamento]

  #ASSOCIATIONS:  
  belongs_to :student, primary_key: :user_id

  def full_address
    aux = ""
    aux += "Municipio #{municipality}, " if municipality
    aux += "Sector #{sector}, " if sector
    aux += "Calle #{street}, " if street
    aux += "#{house_type} #{house_name}. " if (house_type and house_name)
    aux += " #{city_and_state}"
  end

  def city_and_state
    aux = "#{city&.titleize}, " if city
    unless state.blank?
      aux += (state and state.downcase.eql? 'distrito capital') ? " #{state&.titleize}" : " Estado #{state&.titleize}"
    end
    return aux
  end

  def name
    state_and_city
  end
  def state_and_city
    "#{state.titleize} - #{city.titleize}" if (state and city)
  end

  def description
    "#{state_and_city}: #{municipality}. #{sector}: #{street}, #{house_type} #{house_name}"
  end

  # VALIDATIONS:
  validates :student, presence: true
  validates :state, presence: true
  validates :municipality, presence: true
  validates :city, presence: true
  validates :sector, presence: true
  validates :street, presence: true
  validates :house_type, presence: true
  # validates :house_name, presence: true

  def empty_info?
    (state.blank? or municipality.blank? or city.blank? or sector.blank? or street.blank? or house_type.blank?)
  end


  def self.getIndexState stateName
    # aux_states = venezuela.map{|a| a["estado"]}
    self.states.index(stateName)
  end

  def self.getIndexMunicipio stateName, municipalityName
    stateIndex = getIndexState stateName
    venezuela[stateIndex]["municipios"].map{|a| a["municipio"]}.index(municipalityName)
  end

  def self.states
    venezuela.map{|a| a["estado"]}
  end

  def self.municipalities stateName
    Address.venezuela[getIndexState(stateName)]['municipios'].map{|a| a["municipio"]}.sort
  end

  def self.cities stateName, municipalityName
    stateIndex = getIndexState stateName 
    municipalityIndex = getIndexMunicipio(stateName, municipalityName)
        venezuela[stateIndex]["municipios"][municipalityIndex]['parroquias'].map.sort
  end

  def self.venezuela
    require 'json'
    file = File.read("#{Rails.root}/public/venezuela.json")
    JSON.parse(file)
  end

  rails_admin do
    edit do
      fields :state, :municipality, :city, :sector, :street, :house_type, :house_name      
    end
    export do
      exclude_fields :id, :created_at, :updated_at
    end
  end

end
