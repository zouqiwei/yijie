require 'xcodeproj'

project_path = '/Users/mac/Desktop/dexun_work/translate/translate.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the new files to the Xcode target
files = [
  'translate/Models/TranslationHistory.swift',
  'translate/ViewModels/SettingsViewModel.swift',
  'translate/Views/ProfileView.swift'
]

files.each do |file|
  # We look for the main group "translate"
  main_group = project.main_group.children.find { |g| g.display_name == 'translate' || g.path == 'translate' }
  
  # Just add to root if group not found
  group = main_group || project.main_group
  
  # Try to find or create reference
  file_ref = group.find_file_by_path(file) || group.new_reference(file)
  
  # Add to compile sources phase if not already there
  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added #{file} to target #{target.name}"
  else
    puts "#{file} is already in target #{target.name}"
  end
end

project.save
puts "Project saved successfully."
