class Tutorial < ApplicationRecord
  # Shema:
  # t.string "name_function"
  # t.bigint "group_tutorial_id", null: false


  ## Relations
  belongs_to :group_tutorial

  ## HISTORY:
  has_paper_trail on: [:create, :destroy, :update]
  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  ## Rich Text
  has_rich_text :description

  ## Storage
  has_one_attached :video
  attr_accessor :remove_video
  after_save { video.purge if remove_video.eql? '1' }
  after_destroy {video.purge}
  

  ## Validations
  validates :name_function, presence: true
  validates :video, presence: true

  def name
    self.name_function
  end

  def get_url_temp
    (self.video&.attached?) ? Rails.application.routes.url_helpers.rails_blob_path(self.video, only_path: true) : nil
  end

  rails_admin do
    list do
      field :group_tutorial
      field :name_function
      field :video
      field :description
      field :created_at
      field :updated_at
    end		

    edit do
      field :name_function
      field :video
      field :description
    end		

    show do
      field :group_tutorial
      field :name_function

      # field :video do |vid|
      #   video_tag Rails.application.routes.url_helpers.rails_blob_url(vid.video.attachment.blob),:controls=>true, :autobuffer=>true,:size => "200x150" rescue nil
      # end

      # field :video do
      #   pretty_value do
      #     bindings[:view].video_tag(bindings[:object].video.attachment.blob)
      #   end
      # end

      field :video do
        pretty_value do
          bindings[:view].render(partial: '/tutorials/show_video', locals: {url: bindings[:object].get_url_temp})
        end

      end


      field :description
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
      self.paper_trail_event = "¡Tutorial creado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Tutorial eliminado!"
    end
end
