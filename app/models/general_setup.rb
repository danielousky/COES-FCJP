# == Schema Information
#
# Table name: general_setups
#
#  id          :bigint           not null, primary key
#  clave       :string
#  description :string
#  valor       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class GeneralSetup < ApplicationRecord

  def self.enabled_post_qualification?
    var = GeneralSetup.where(clave: "ENABLED_POST_QUALIFICACION").first
    (var&.valor&.casecmp("SI") == 0 or var&.valor&.casecmp("SÍ") == 0) ? true : false
  end

  def self.disable_for_non_payment?
    var = GeneralSetup.where(clave: "DISABLED_NON_PAYMENT").first
    (var&.valor&.casecmp("SI") == 0 or var&.valor&.casecmp("SÍ") == 0) ? true : false
  end

  def self.send_wellcome_mailer_on_create_user? 
    
    var = GeneralSetup.where(clave: "SEND_WELLCOME_MAILER_ON_CREATE_USER").first
    (var&.valor&.casecmp("SI") == 0 or var&.valor&.casecmp("SÍ") == 0) ? true : false
  end
  
end
