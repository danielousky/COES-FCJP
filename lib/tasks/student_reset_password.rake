namespace :students do
  desc "Reset student user passwords to their CI"
  task reset_passwords: :environment do
    Student.includes(:user).find_each do |student|
      begin
        if student.user.update(password: student.user.ci)
            print '.' 
        else
            puts "Failed to update password for student ID #{student.id}: #{student.user.errors.full_messages.join(', ')}"
            
        end
      rescue => e
        puts "Error updating password for student ID #{student.id}: #{e.message}"
        next
      end
    end
    puts "Passwords reset completed."
  end
end
