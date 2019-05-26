(require 'json)

(defun mjp/match-file-contents (regex filePath)
  "Matches a regular expression with contents in another file"
  (let ((fContents (with-temp-buffer (insert-file-contents filePath nil)
                                     (buffer-string))))
    (string-match regex fContents)
    (match-string 1 fContents)))


(spacemacs/declare-prefix "ah" "hass-api")
(spacemacs/declare-prefix "ahr" "refresh")

(defun hass-api/get-all-entities-as-list()
  "Use curl to grab a list of all entities from home assistant"
  (let* ((hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
         (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                            "~/hassio-config-euler/hass-token.txt"))
         (entity_ids (shell-command-to-string (concat "curl -s -H \"Content-Type: application/json\" "
                              "-H \"Authorization: Bearer "
                              hass-token
                              "\" "
                              hass-url
                              "/api/template "
                              "-d"
                              "\"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\n{% endfor %}\\\"}\""))))
    (split-string entity_ids "\n")))

(defun hass-api/refresh-entities()
  "Download latest entities from Home Assistant"
  (interactive)
  (setq hass-api/entities (hass-api/get-all-entities-as-list)))

(hass-api/refresh-entities)
(spacemacs/set-leader-keys "ahre" 'hass-api/refresh-entities)

(defun hass-api/get-all-entities-and-names-as-list()
  "Use curl to grab a list of all entities and their friendly names from home assistant"
  (let* ((hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
         (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                            "~/hassio-config-euler/hass-token.txt"))
         (entity_ids (shell-command-to-string
                      (concat "curl -s -H \"Content-Type: application/json\" "
                              "-H \"Authorization: Bearer "
                              hass-token
                              "\" \""
                              hass-url
                              "/api/template\" "
                              "-d"
                              "\"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\t'{{state.attributes.friendly_name}}'\\n{% endfor %}\\\"}\""))))
    (split-string entity_ids "\n")))

(defun hass-api/refresh-entities-and-names()
  "Download latest entities from Home Assistant"
  (interactive)
  (setq hass-api/entities-and-names (hass-api/get-all-entities-and-names-as-list)))

(hass-api/refresh-entities-and-names)
(spacemacs/set-leader-keys "ahrn" 'hass-api/refresh-entities-and-names)

;; (defun hass-api/get-all-services-as-list())

(defun hass-api/gitpull-restart()
  "Restart the hassio Git Pull addon"
  (interactive)
  (save-excursion
    (let* ((hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)" "~/hassio-config-euler/hass-token.txt"))
          (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                           "~/hassio-config-euler/hass-token.txt"))
          (curl-command (concat "curl \"-i\" \"-H\" \"Content-Type: application/json\" \"-H\" \"Authorization: Bearer "
                                hass-token
                                "\" \"-XPOST\" \""
                                hass-url
                                "/api/services/hassio/addon_restart\" "
                                "\"-d\" \"{\\\"addon\\\":\\\"core_git_pull\\\"}\"")))
      (async-shell-command curl-command "*hassio*" "*httperror*")
      )
    )
  )

(defun hass-api/get-all-entities()
  "Get all Entity Id's from Home Assistant"
  (interactive)
  (save-excursion
    (let* ((hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                                "~/hassio-config-euler/hass-token.txt"))
           (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
           (curl-command (concat "curl -H \"Content-Type: application/json\" "
                                 " -H \"Authorization: Bearer "
                                 hass-token
                                 "\" \"-XPOST\" \""
                                 hass-url
                                 "/api/template\" "
                                 "\"-d\" \"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\n{% endfor %}\\\"}\"")))
      (async-shell-command curl-command "*hassio*" "*httperror*"))))

(defun hass-api/get-state-by-entity(&optional entity_id)
  "Get the state properties of the entity provided"
  (interactive)
  (save-excursion
    (let* ((entity_id (or entity_id (hass-api/get-entity-from-list)))
           (hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                                "~/hassio-config-euler/hass-token.txt"))
           (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
           (curl-command (concat "curl -H \"Content-Type: application/json\" "
                                 "-H \"Authorization: Bearer "
                                 hass-token
                                 "\" -X GET "
                                 hass-url
                                 "/api/states/"
                                 entity_id)))
      (async-shell-command curl-command "*hassio*" "*httperror*")
      (message "Entities obtained"))))

(spacemacs/set-leader-keys "ahs" 'hass-api/get-state-by-entity)

(defun hass-api/get-entity-from-list()
  "Get the state properties of the entity provided"
  (save-excursion
    (let* ((entity_id (helm :sources
                             (helm-build-sync-source "HA Entities"
                               :candidates hass-api/entities-and-names
                               :fuzzy-match t))))
      (car (split-string entity_id "\t")))))


;; (hass-api/get-entity-from-list)
(defun hass-api/get-entity-from-list-to-buffer()
  "Output selected entity id from a helm list of entities"
  (interactive)
  (save-excursion
    (let* ((entity_id (hass-api/get-entity-from-list)))
      (forward-char)
      (insert entity_id))))

(spacemacs/set-leader-keys "ahe" 'hass-api/get-entity-from-list-to-buffer)

(defun hass-api/get-state-from-list()
  "Get entity state from a helm list of entities"
  (interactive)
  (let* ((entity_id (hass-api/get-entity-from-list))
         (hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
         (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                            "~/hassio-config-euler/hass-token.txt"))
         (template_statement
          (concat "\"{\\\"template\\\":\\\""
                  "{{ states." entity_id
                  " }}"
                  "\\\"}\"")
          ))
    (message "%s" (shell-command-to-string
                   (concat "curl -s -H \"Content-Type: application/json\" "
                           "-H \"Authorization: Bearer "
                           hass-token
                           "\" "
                           hass-url
                           "/api/template "
                           "-d"
                           template_statement)))))
(spacemacs/set-leader-keys "ahs" 'hass-api/get-state-from-list)

(defun hass-api/template(arg)
  "Run supplied template as `arg' on Home Assistant instance"
  (interactive "sTemplate: ")
  (let* ((hass-token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
         (hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                            "~/hassio-config-euler/hass-token.txt"))
         (arg (concat "{\\\"template\\\":\\\"" arg "\\\"}"))
         )
    (unless arg
      (error "No temlate provided"))
    (async-shell-command
     (concat "curl -s -H \"Content-Type: application/json\" "
             "-H \"Authorization: Bearer "
             hass-token
             "\" "
             hass-url
             "/api/template "
             "-d \"" arg "\"")
     "*HA Template*"
     "*HA Error*")
    (message "Template: %s" arg)))

(defun mjp/browse-url-hassio()
  "Browse to the hassio url specified in hass-token.txt"
  (interactive)
  (let ((hass-url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                           "~/hassio-config-euler/hass-token.txt")))
    (browse-url hass-url)
    (message "%s" hass-url)))
(spacemacs/set-leader-keys "ahh" 'mjp/browse-url-hassio)

(provide 'hass-api)
