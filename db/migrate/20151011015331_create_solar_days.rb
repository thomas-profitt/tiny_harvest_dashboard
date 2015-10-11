class CreateSolarDays < ActiveRecord::Migration
  def change
    create_table :solar_days do |t|
      t.date :date
      t.decimal :latitude
      t.decimal :longitude
      t.datetime :sunrise_at
      t.datetime :solar_noon_at
      t.datetime :sunset_at

      t.timestamps null: false
    end
  end
end
