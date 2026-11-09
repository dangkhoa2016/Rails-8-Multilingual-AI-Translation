Rails.application.config.filter_parameters += %i[
  password password_confirmation api_token authorization token secret
  source_text translation_text base_url remote_status_path
  glossary_snapshot source_term target_term notes
  client_request_key provider_response_json
]
