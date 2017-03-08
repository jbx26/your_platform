class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Patch the `#first` method to allow the following for STI classes
  # like `Group`, which has descendant classes like `Groups::Everyone`.
  #
  # - `Group.first` should return the first group regardless of the type,
  #   i.e. `Groups::Everyone` might be the first group.
  # - `Groups::Everyone` should return the first group of the subclass
  #   type.
  #
  def self.first
    if self.column_names.include?('type') && (self != self.base_class)
      self.where(type: self.name).first
    else
      super
    end
  end
end