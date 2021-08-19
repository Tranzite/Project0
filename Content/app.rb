require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'
enable :sessions

include Helper

before do
    #p "Before KÖRS, session_user_id är #{session[:id]}."
    if session[:id] != 1
        if (request.path_info == '/klasser/new') || (request.path_info == '/klasser/:id/edit')
            session[:error] = "No permission."
            redirect('/error')
        end
    end
    if (session[:id] == nil) && (request.path_info == '/cart')
        session[:error] = "You need to log in to view this page."
        redirect('/error')
    end
end
  
# Displays error page
get('/error') do
    slim(:error)
end

# Displays landing page
get('/') do
    sleep(3)
    db = connect_db("db/webshop.db")
    id = 1
    result = db.execute("SELECT * FROM students WHERE class_id = ?",id)
    slim(:index, locals:{result:result})
end 

# Displays all items contained in the database
get('/klasser') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM categories")
    slim(:"items/index",locals:{categories:result})
end

# Displays page to create new item
get('/klasser/new') do
    db = connect_db("db/webshop.db")
    slim(:"items/new")
end

# Creates a new item and redirects to /items
#
# @param [String] item_name
# @param [Integer] price
# @param [Integer] stock
# @param [String] path
# @param [String] description
# @param [String] category
#
# @return item is created & categories_items_relation updated
post('/klasser/new') do
    db = connect_db("db/webshop.db")
    class_name = params[:class_name]
    # stock = params[:stock].to_i
    # price = params[:price].to_i
    # if params[:image] && params[:image][:filename]
    #     filename = params[:image][:filename]
    #     file = params[:image][:tempfile]
    #     path = "./public/img/#{filename}"
    #     File.open(path, 'wb') do |f|
    #         f.write(file.read)
    #     end
    #     path = "img/#{filename}"
    # end

    params = [class_name] #,stock,price,path,description,category]
    is_valid(params)

    #db.execute("INSERT INTO items (name,stock,price,image,description) VALUES (?,?,?,?,?)",item_name,stock,price,path,description)
    db.execute("INSERT INTO categories (category) VALUES (?)",class_name)

    #Lägger in i många till många-tabellen
    # id_category = db.execute("SELECT * FROM categories WHERE category = ?",category).first
    # item_id = db.execute("SELECT id FROM items ORDER BY id DESC LIMIT 1").first
    # db.execute("INSERT INTO categories_items_relation (item_id,category_id) VALUES (?,?)",item_id[0],id_category[0])
    redirect('/klasser')
end

get('/klasser/:id/new') do
    id = params[:id].to_i
    slim(:"items/newstudent", locals:{id: id})
end

post('/klasser/:id/new') do
    db = connect_db("db/webshop.db")
    student = params[:student_name]
    id = params[:id].to_i
    if params[:image] && params[:image][:filename]
        filename = params[:image][:filename]
        file = params[:image][:tempfile]
        path = "./public/img/#{filename}"
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
        path = "img/#{filename}"
    end
    param = [student, path]
    is_valid(param)
    db.execute("INSERT INTO students (name,image,class_id) VALUES (?,?,?)",student,path,id)
    redirect("/klasser/#{id}")
end

# Deletes an item and redirects to /items
#
# @param [Integer] id Id of the item
post('/klasser/:id/delete') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    db.execute("DELETE FROM categories WHERE id = ?", id)
    db.execute("DELETE FROM cart WHERE item_id = ?", id)
    redirect('/klasser')
end

# Updates the params of an item and redirects to /items
#
# @param [Integer] id Id of item
# @param [String] item_name
# @param [Integer] price
# @param [Integer] stock
# @param [String] description
#
# @return item is updated
post('/klasser/:id/update') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    item_name = params[:item_name]
    stock = params[:stock].to_i
    price = params[:price].to_i
    description = params[:description]

    params = [item_name,stock,price,description,id]
    is_valid(params)

    db.execute("UPDATE items SET name = ?,stock = ?,price = ?,description = ? WHERE id = ?",item_name,stock,price,description,id)
    redirect('/klasser')
end

# Adds an item to the users cart and redirects to /items
#
# @param [Integer] id 
# @param [Integer] item_count
# 
# @return item is added to users cart
post('/klasser/:id/add_item') do
    db = connect_db("db/webshop.db")
    item_count = params[:item_count]
    id = params[:id].to_i

    result = db.execute("SELECT * FROM items WHERE id = ?", id).first  

    params = [item_count]
    is_valid(params)

    db.execute("INSERT INTO cart (user_id,item_id,item_count) VALUES (?,?,?)",session[:id],result["id"],item_count)
    redirect('/klasser')
end

# Displays interface to edit item
get('/klasser/:id/edit') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    result = db.execute("SELECT * FROM items WHERE id = ?", id).first
    result2 = db.execute("SELECT * FROM categories")
    slim(:"/items/edit", locals:{result:result,categories:result2})
end
  
# Displays item
get('/klasser/:id') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    result = db.execute("SELECT * FROM students WHERE class_id = ?",id)
    p result
    slim(:"items/show",locals:{result:result, class_id: id})
end

# Displays the users cart
get('/cart') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM cart WHERE user_id = ?",session[:id])
    result2 = []
    result.each do |item|
        result2 << db.execute("SELECT * FROM items WHERE id = ?",item['item_id'])
    end
    slim(:"cart/index",locals:{cart:result,items:result2})
end

# Displays a login page
get('/login') do
    slim(:"users/login")
end
  
# The user is logged in and redirected to /items
#
# @param [String] username
# @param [String] password
#
# @see Model#login
post('/login') do
    username = params[:username]
    password = params[:password]

    login(username, password)
end

# Displays a register page
get('/register') do
    slim(:"users/register")
end

# The user is registred and redirected to /login
#
# @param [String] username
# @param [String] password
# @param [String] password_confirm
# @param [String] adress
#
# @see Model#register
post('/register') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    register(username, password, password_confirm)
end

# The user is logged out and redirected to /
post('/logout') do
    session[:id] = nil
    redirect('/')
end