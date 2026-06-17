-- Tables importing

-- -->Go to create a new Schema in the connected server.
-- --> Name your new Schema or Data base('sql_major_project') and press apply.
-- -->It will open a pop up tab as "Review the SQL script to be applied", press apply and then finish in the next page.
   /*Successfully you had created your Data base('sql_major_project'), Now we need to load our CSV files into the Data base.*/
-- -->  Double click on the Data base ('sql_major_project').Now we will be using this Data base.
-- --> Right click on the Data base ('sql_major_project') and select "Table Data Import WIzard".
--                  It will open a pop up tab as "Select file to import"
--                  Broswe the files you need to import from the local data or other sources. Later press "NEXT" for the next 5 consecutive pop ups and later "Finish".
	/* Your CSV files had beed imported successfully into your MYSQL Data base server*/
               
show databases;
show tables;

-- Table columns checking
select * from customer_behavior;
select * from   customers;
select * from delivery_partners;
select * from orders;
select * from payments;
select * from restaurants;
select * from ratings;

-- Tables descriptions
desc customer_behavior;
desc customers;
desc delivery_partners;
desc orders;
desc payments;
desc restaurants;
desc ratings;

-- Constrains allocations

alter table customer_behavior
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);
alter table customer_behavior
modify column total_spending decimal(50,2);
alter table customer_behavior
modify column avg_order_value decimal(50,2) not null;
alter table customer_behavior
modify column last_order_days int not null;
alter table customer_behavior
modify column churn_flag int check (churn_flag IN (0,1));

alter table customers
modify column customer_id int primary key;
alter table customers
modify column customer_name varchar(100) not null;
alter table customers
modify column city varchar(50) not null;
alter table customers
modify column signup_date date; 

alter table delivery_partners
modify partner_id int primary key;
alter table delivery_partners
modify column partner_name varchar(100) not null;
alter table delivery_partners
modify column joining_date date;

alter table orders
modify column order_id int primary key;
ALTER TABLE orders
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);
ALTER TABLE orders
ADD CONSTRAINT fk_restaurant
FOREIGN KEY (restaurant_id)
REFERENCES restaurants(restaurant_id);
alter table orders
add constraint fk_partner
foreign key ( partner_id)
references delivery_partners(partner_id);
alter table orders
modify column order_time time;
alter table orders
modify column delivered_time time;
alter table orders
modify column delivery_fee decimal(10,2);
alter table orders
modify column status varchar(100);

alter table restaurants
modify column restaurant_id int primary key;
alter table restaurants
modify column cuisine_type varchar(100);
alter table restaurants
modify column city varchar(100);
alter table restaurants
modify column rating decimal(10,2); 

alter table ratings
modify column rating_id int primary key;
alter table ratings
modify column customer_rating decimal(10,2);
alter table ratings
modify column feedback varchar(500);
alter table ratings
add constraint fk_order
foreign key ( order_id)
references orders(order_id);