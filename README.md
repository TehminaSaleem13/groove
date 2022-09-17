GroovePacker
============
hello

While installing on a Ubuntu server, install the libexpat1-dev library to fix the xmlparser gem installation
sudo apt-get install libexpat1-dev

# Create User for Mysql otherwise change the values for database credentials in env files for the environment
`sudo mysql -u root -p`
`CREATE USER 'groovepacker'@'localhost' IDENTIFIED BY 'password';`
`GRANT ALL PRIVILEGES ON *.* TO 'groovepacker'@'localhost';`
`FLUSH PRIVILEGES;`
