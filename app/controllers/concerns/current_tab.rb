concern :CurrentTab do
  
  included do
    helper_method :current_tab, :current_tab_path
  end
  
  # This method returns the correct path for the given object
  # considering the current tab the user has used last.
  #
  def current_tab_path(object)
    if object.kind_of?(Group) and can?(:use, :tab_view)
      case current_tab(object)
      when "subgroups"; group_subgroups_path(object)
      when "posts"; group_posts_path(object)
      when "profile"; group_profile_path(object)
      when "events"; group_events_path(object)
      when "members"; group_members_path(object)
      when "officers"; group_officers_path(object)
      when "settings"; group_settings_path(object)
      else group_profile_path(object)
      end
    else
      object
    end
  end
  
  def current_tab(object = nil)
    object ||= current_navable
    if object.kind_of?(Group)
      if object.group_of_groups?
        "subgroups"
      else
        cookies[:group_tab]
      end
    end
  end
  
end