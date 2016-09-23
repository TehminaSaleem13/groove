package main

import (
	"database/sql"
	"fmt"
	sq "github.com/Masterminds/squirrel"
	_ "github.com/go-sql-driver/mysql"
	"github.com/joho/godotenv"
	"log"
	"os"
	_ "strconv"
	"time"
)

type CONFIG struct {
	DB_HOST string
	DB_NAME string
	DB_USER string
	DB_PASS string
}

type Tenant struct {
	Name             string
	OrdersDeleteDays int
}

var (
	ENV            CONFIG
	IntTenant      string
	IntDeleteCount string
)

func main() {

	intialize()

	// Setup Connection with default DB
	// To get all the tenant names
	db := sql_open(ENV.DB_NAME)
	defer db.Close()
	tenants := collect_tenant_names(db)

	for _, tenant := range tenants {
		perform_deletion(tenant)
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
		IntTenant = os.Args[1]
		IntDeleteCount = os.Args[2]
	}

	fmt.Println(IntTenant, IntDeleteCount)
}

func sql_open(db_name string) *sql.DB {
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
func collect_tenant_names(db *sql.DB) []Tenant {
	var query string

	if len(IntTenant) > 0 {
		query = "SELECT name, orders_delete_days FROM `tenants` WHERE name = \"" + IntTenant + "\""
	} else {
		query = "SELECT name, orders_delete_days FROM `tenants` ORDER BY name"
	}

	rows, err := db.Query(query)
	// Close query
	defer rows.Close()
	if err != nil {
		log.Fatal(err)
	}

	tenants := make([]Tenant, 0)

	for rows.Next() {
		tenant := new(Tenant)
		err := rows.Scan(&tenant.Name, &tenant.OrdersDeleteDays)
		if err != nil {
			log.Fatal(err)
		}
		tenants = append(tenants, *tenant)
	}

	err = rows.Err()
	if err != nil {
		log.Fatal(err)
	}

	log.Println(tenants)
	return tenants
}

func time_zone(location string) *time.Location {
	zone, err := time.LoadLocation(location)
	if err != nil {
		fmt.Println("err: ", err.Error())
	}
	return zone
}

func perform_deletion(tenant Tenant) {
	db := sql_open(tenant.Name)
	defer db.Close()

	orders_ids := orders_ninety_days_ago_ids(db)

	if len(IntDeleteCount) > 0 {
		orders_ids = append(orders_ids, orders_custom_days_ids(db)...)
	}

	//delete_orders_days := tenant.OrdersDeleteDays
	log.Println(orders_ids)
}

func orders_ninety_days_ago_ids(db *sql.DB) []int {
	var orders_ids []int

	rows, err := sq.
		Select("id").
		From("orders").
		Where("updated_at < ?",
			time.Now().AddDate(0, 0, -90).In(time_zone("Asia/Kolkata")).Format("2006-01-02 15:04:05")).
		RunWith(db).Query()

	defer rows.Close()
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		var id int
		err := rows.Scan(&id)
		if err != nil {
			log.Fatal(err)
		}
		orders_ids = append(orders_ids, id)
	}

	return orders_ids
}

func orders_custom_days_ids(db *sql.DB) []int {
	var orders_ids []int
	return orders_ids
}