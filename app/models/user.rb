class User < ActiveRecord::Base
  enum role: [:user, :vip, :admin]
  after_initialize :set_default_role, :if => :new_record?
  before_create :make_payment, unless: Proc.new { |user| user.admin? }
  after_validation :set_coupon
  # after_create :sign_up_for_mailing_list
  attr_accessor :stripe_token

  belongs_to :coupon
  accepts_nested_attributes_for :coupon
  validates_associated :coupon

  def set_default_role
    self.role ||= :user
  end

  def set_coupon
    return false if errors.any?
    return false if self.coupon.nil?
    coupon = Coupon.find_by code: self.coupon.code
    self.coupon = coupon
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  def make_payment
    MakePaymentService.new.perform(self)
  end

  def sign_up_for_mailing_list
    MailingListSignupJob.perform_later(self)
  end

  def subscribe
    mailchimp = Gibbon::API.new(Rails.application.secrets.mailchimp_api_key)
    result = mailchimp.lists.subscribe({
      :id => Rails.application.secrets.mailchimp_list_id,
      :email => {:email => self.email},
      :double_optin => false,
      :update_existing => true,
      :send_welcome => true
    })
    Rails.logger.info("Subscribed #{self.email} to MailChimp") if result
  end

end
