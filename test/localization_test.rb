require "test_helper"

class LocalizationTest < ActiveSupport::TestCase
  test "English and Vietnamese catalog have matching UI keys" do
    catalogs = %i[en vi].to_h do |locale|
      document = YAML.safe_load_file(Rails.root.join("config/locales/#{locale}.yml"))
      [locale, flatten_keys(document.fetch(locale.to_s))]
    end
    assert_equal catalogs[:en].sort, catalogs[:vi].sort
    assert_equal %i[en vi], I18n.available_locales.sort
  end

  test "locale is scoped rather than leaking between requests" do
    assert_equal "Administrator sign in", I18n.with_locale(:en) { I18n.t("auth.sign_in_title") }
    assert_equal "Đăng nhập quản trị", I18n.with_locale(:vi) { I18n.t("auth.sign_in_title") }
  end

  private

  def flatten_keys(value, prefix = nil)
    return [prefix] unless value.is_a?(Hash)
    value.flat_map do |key, child|
      flatten_keys(child, [prefix, key].compact.join("."))
    end
  end
end
