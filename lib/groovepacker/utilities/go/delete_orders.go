package main

import (
  "database/sql"
  _ "github.com/go-sql-driver/mysql"
  "github.com/joho/godotenv"
  "os"
  "log"
  _ "strconv"
  "fmt"
)

type CONFIG struct {
  DB_HOST string
  DB_NAME string
  DB_USER string
  DB_PASS string
}

var(
  ENV CONFIG
  Tenant string
  DeleteCount string
)

func main() {
  
  intialize()
  
  // Setup Connection with default DB
  // To get all the tenant names
  db := sql_open(ENV.DB_NAME)
  defer db.Close()
  tenant_names := collect_tenant_names(db)

  for _, name := range tenant_names {
    go perform_deletion(name)
  }
}

func intialize() {
  _ = godotenv.Load("../../../../.env")

  // DB Config
  ENV.DB_HOST = "tcp(" + os.Getenv("DB_HOST") + ":3306)"
  ENV.DB_NAME = "groovepacks_development"
  ENV.DB_USER = os.Getenv("DB_USERNAME")
  ENV.DB_PASS = os.Getenv("DB_PASSWORD")

  fmt.Println(ENV)

  // Intial Variables
  if len(os.Args) > 2 {
    Tenant = os.Args[1]
    DeleteCount = os.Args[2]
  }

  fmt.Println(Tenant, DeleteCount)
}

func sql_open(db_name string) *sql.DB{
  // user:password@host/DB?charset=utf8
  dsn := ENV.DB_USER + ":" + ENV.DB_PASS +
         "@" + ENV.DB_HOST + "/" + db_name +
         "?charset=utf8"
  db, err := sql.Open("mysql", dsn)
  if err != nil {
    log.Fatal(err)
  }

  err = db.Ping()
  if err != nil {
    log.Fatal(err)
  }

  return db
}

  //
func collect_tenant_names(db *sql.DB) []string {
  var query string
  
  if len(Tenant) > 0 {
    query = "SELECT name FROM `tenants` WHERE name = \"" + Tenant + "\""
  }else{
    query = "SELECT name FROM `tenants` ORDER BY name"
  }
  
  rows, err := db.Query(query)
  // Close query
  defer rows.Close()

  if err != nil {
    log.Fatal(err)
  }
  
  tenant_names := make([]string, 0)
  var name string

  for rows.Next() {
    err := rows.Scan(&name)
    if err != nil {
      log.Fatal(err)
    }
    tenant_names := append(tenant_names, name)
    log.Println(tenant_names)
  }
  
  err = rows.Err()
  if err != nil {
    log.Fatal(err)
  }

  return tenant_names
}

func perform_deletion(tenant_name string) {
  db := sql_open(ENV.DB_NAME)
}