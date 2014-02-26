# Nach dem Import der Benutzer sind einige Patches erforderlich, um fehlerhafte Daten
# in der Netenv-Datenbank zu korrigieren.
#
# Siehe Trello: https://trello.com/c/KI457uFK/540-import-patches
#
namespace :patch do

  # Beachtung der Reihenfolge wichtig!
  #
  task :users => [
    'environment',                                       # Nummerierung gemäß der Kommentare in Trello:
    'users:requirements',                                # https://trello.com/c/KI457uFK/540-import-patches
    'users:print_info',                                  #
    'fix:officers',                                      # (6) Amtsträger-Gruppen
    'users:reimport_ef_corporation_memberships',         # (3) Ef-Aktive erneut importieren
    'users:delete_users_without_ldap_assignments',       # (4) Benutzer ohne LDAP-String löschen
    'users:hide_non_wingolfits',                         # (1) Nicht-Wingolfiten verstecken
    'users:subsequent_philistrations',                   # (5) Philistrationen nachreichen
    'users:find_users_with_missing_wv_or_phv_membership' # (2) Auf weitere Inkonsistenzen überprüfen
  ]
  
  namespace :users do
    
    task :requirements do
      require 'importers/models/log'
      require 'importers/importer'
      require 'importers/models/netenv_user'
      require 'importers/models/user'
      require 'importers/models/string'
    end
        
    task :print_info => [:requirements] do
      log.head "User Patcher"
      log.info "Dieser Task führt Korrekturen durch, die nach einem abgeschlossenen 'rake import:users' notwendig sind."
      log.info "Trello: https://trello.com/c/KI457uFK/540-import-patches"
      log.info ""
    end
    
    task :subsequent_philistrations => [:environment, :requirements, :print_info] do
      log.section "Philistrationen nachreichen."
      log.info "Ein Benutzer kann idR. nicht gleichzeitig Aktiver und Philister sein. Bei solchen Benutzern"
      log.info "ist wahrscheinlich die Information über die Philistration verloren gegangen."
      log.info "Die Korporations-Mitgliedschaften dieser Benutzer müssen (mit dem verbsserten"
      log.info "Import-System) neu importiert werden."
      log.info ""
      log.info "Betroffene Fälle:"
      
      User.find_each do |user|
        if user.wingolfit? and user.aktiver? and user.philister?
          user.import_corporation_memberships_from user.netenv_user
          log.info "#{user.title} (#{user.w_nummer})"
        end
      end
    end
    
    task :hide_non_wingolfits => [:environment, :requirements, :print_info] do
      log.section "Nicht-Wingolfiten verstecken"
      log.info "Alle Benutzer, die keine Wingolfiten sind, sollen als versteckt markiert werden,"
      log.info "damit sie nur von Administratoren gesehen werden können."
      log.info ""
      log.info "Im Moment versteckte Benutzer: #{Group.hidden_users.members.count}"
      log.info ""
      log.info "Korrigiere Benutzer:"
      
      User.find_each do |user|
        if (not user.wingolfit?) and (not user.hidden?)
          user.hidden = true
          log.info "#{user.title} (#{user.w_nummer})"
        end
      end

      log.info ""
      log.info "Nach der Korrektur versteckte Benutzer: #{Group.hidden_users.members.count}"
    end
    
    task :delete_users_without_ldap_assignments => [:environment, :requirements, :print_info] do
      log.section "Benutzer ohne LDAP-Zuordnung löschen."
      log.info "Benutzer ohne LDAP-Zuordnung werden in Netenv als gelöscht betrachtet,"
      log.info "ohne dabei gesondert als gelöscht markiert zu sein."
      log.info "Daher muss für alle Netenv-Benutzer ohne LDAP-Zuordnung sichergestellt"
      log.info "werden, dass sie im neuen System nicht vorhanden sind."
      log.info ""
      log.info "Gelöschte Benutzer:"
      
      NetenvUser.find_each do |netenv_user|
        if (netenv_user.ldap_assignments.count == 0) and (not netenv_user.deleted?)
          user = User.find_by_w_nummer(netenv_user.w_nummer)
          if user
            user.destroy
            log.info "#{netenv_user.name} (ehemals #{netenv_user.w_nummer})"
          end
        end
      end
    end
    
    task :find_users_with_missing_wv_or_phv_membership => [:environment, :requirements, :print_info] do
      log.section "Inkonsistenzen suchen: Benutzer mit fehlender WV- oder PhV-Mitgliedschaft."
      log.info "Es gibt Benutzer (z.B. W54613), deren Aktivitätszahl nicht aktualisiert wurde,"
      log.info "als die Mitgliedschaft endete. Dank der Aktivitätszahl wurden sie aber wieder"
      log.info "in die entsprechenden Korporationen importiert, was nun korrigiert werden muss."
      log.info ""
      log.info "Da der Zustand nicht eindeutig rekonstruierbar ist, ist hier manuelle Eingabe"
      log.info "erforderlich. Einige Benutzer wurden bereits überprüft. Bitte Ergebnisse von"
      log.info "https://trello.com/c/KI457uFK/540-import-patches vergleichen."
      log.info ""
      log.warning "Möglicher Handlungsbedarf bei:"
      log.warning ""

      User.find_each do |user|
        if user.aktivitätszahl.present?
          for corporation in user.corporations
            if (not corporation.token.include? "!") and # keine Schweizer, da für diese keine LDAP-Gruppen existieren
              not (user.guest_of?(corporation)) and 
              not (user.former_member_of_corporation?(corporation)) and
              (user.alive?) and
              (user.netenv_user.ldap_assignments_in(corporation).count == 0)

              log.warning "#{user.title} (#{user.w_nummer})"
            end
          end
        end
      end
      
    end
    
    task :reimport_ef_corporation_memberships => [:environment, :requirements, :print_info] do
      log.section "Re-Import der Erfurter Aktiven"
      log.info "Da Erfurt (Ef) im Netenv-LDAP als 'Erf' kodiert war, ist hier ein erneuter Import"
      log.info "der UserGroupMemberships der Korporationen der Erfurter Aktiven von Nöten,"
      log.info "um ihren aktuellen Aktivenstatus korrekt in das neue System zu übertragen."
      log.info ""
      log.info "Korrigierte Benutzer:"
      
      users = Corporation.find_by_token("Ef").aktivitas.members.to_a
      # users = [ User.find_by_w_nummer("W52386") ]
      
      users.each do |user|
        user.import_corporation_memberships_from user.netenv_user
        log.info "#{user.title} (#{user.w_nummer})"
      end
    end
    
  end
  
  def log
    $log ||= Log.new
  end
  
end

