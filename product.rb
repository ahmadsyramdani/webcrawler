require 'sqlite3'
require 'pry'

class Product
  def self.connection
    db = SQLite3::Database.open("./db/development.sqlite3")
    r = yield db
    db.close
    return r
  end

  def self.exists?(name)
    result = self.connection do |db|
      db.execute("select count() from products where name = ?", [name])
    end

    return result[0][0] > 0
  end

  def self.create(params)
    result = self.connection do |db|
      db.execute("INSERT INTO products(name, price, description, extra_description) VALUES(?, ?, ?, ?)", params)
    end
    return result
  end
end
