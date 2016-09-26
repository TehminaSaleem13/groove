package main

import (
	"database/sql"
	"fmt"
	sq "github.com/Masterminds/squirrel"
	_ "github.com/go-sql-driver/mysql"
	"github.com/joho/godotenv"
	// "io/ioutil"
	"log"
	"os"
	// "os/exec"
	"runtime"
	_ "strconv"
	"strings"
	"sync"
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
	ENV       CONFIG
	IntTenant string
	// IntDeleteCount int
	wg sync.WaitGroup
)

func main() {

	f, err := os.OpenFile("log/go.log", os.O_RDWR | os.O_CREATE | os.O_APPEND, 0666)
	if err != nil {
	    log.Println("error opening file: %v", err)
	}
	defer f.Close()

	log.SetOutput(f)

	start_time := time.Now()
	intialize()

	// Setup Connection with default DB
	// To get all the tenant names
	db := sql_open(ENV.DB_NAME)
	defer db.Close()
	tenants := collect_tenant_names(db)

	// tenant_backup(tenants)

	for _, tenant := range tenants {
		wg.Add(1)
		go func(tenant Tenant) {
			perform_deletion(tenant)
			wg.Done()
		}(tenant)
	}

	wg.Wait()
	end_time := time.Since(start_time)
	log.Println("Deletion Completed In (", end_time, ")")
}

func intialize() {
	runtime.GOMAXPROCS(runtime.NumCPU())

	// Intial Variables
	if len(os.Args) > 2 {
		IntTenant = os.Args[2]
		// IntDeleteCount = 100 //os.Args[2]
	}

	log.Println(IntTenant)

	_ = godotenv.Load(".env")

	// DB Config
	ENV.DB_HOST = os.Getenv("DB_HOST")
	ENV.DB_NAME = os.Args[1]
	ENV.DB_USER = os.Getenv("DB_USERNAME")
	ENV.DB_PASS = os.Getenv("DB_PASSWORD")

	log.Println(ENV)

}

func sql_open(db_name string) *sql.DB {
	// user:password@host/DB?charset=utf8
	dsn := ENV.DB_USER + ":" + ENV.DB_PASS +
		"@" + "tcp(" + ENV.DB_HOST + ":3306)" + "/" + db_name +
		"?charset=utf8"
	log.Println(dsn)

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

// func tenant_backup(tenants []Tenant) {

// 	for _, tenant := range tenants {
// 		func(){

// 			file_path := "public/delete_orders/" +
// 				tenant.Name + "-" +
// 				time.Now().In(time_zone("Asia/Kolkata")).Format("2006-01-02") +
// 				".sql"

// 			log.Println("Creating Backup for Tenant : ", tenant.Name)

// 			args := []string{
// 				"-h" + ENV.DB_HOST,
// 				"-u" + ENV.DB_USER,
// 				"-p" + ENV.DB_PASS,
// 				tenant.Name,
// 			}

// 			cmd := exec.Command("mysqldump", args...)
// 			stdout, err := cmd.StdoutPipe()
// 			if err != nil {
// 				log.Fatal(err)
// 			}

// 			if err := cmd.Start(); err != nil {
// 				log.Fatal(err)
// 			}

// 			bytes, err := ioutil.ReadAll(stdout)
// 			if err != nil {
// 				log.Fatal(err)
// 			}

// 			err = ioutil.WriteFile(file_path, bytes, 0644)
// 			if err != nil {
// 				panic(err)
// 			}

// 			log.Println("Backup File Created : ", file_path)
// 		}()
// 	}
// }

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

	order_ids := orders_ninety_days_ago_ids(db)
	delete_order_days := tenant.OrdersDeleteDays

	if delete_order_days > 0 {
		order_ids = append(order_ids, orders_custom_days_ids(delete_order_days, db)...)
		order_ids = removeDuplicates(order_ids)
	}

	if len(order_ids) == 0 {
		log.Println("No Orders Found !!!")
		return
	}

	//if IntDeleteCount > 0 {
	//	order_ids = order_ids[:IntDeleteCount]
	//}

	delete_orders(order_ids, db)
}

func orders_ninety_days_ago_ids(db *sql.DB) []string {
	var order_ids []string

	query := sq.
		Select("id").
		From("orders").
		Where("updated_at < ?",
			time.Now().AddDate(0, 0, -90).In(time_zone("Asia/Kolkata")).Format("2006-01-02 15:04:05")).
		RunWith(db)
	log.Println(query.ToSql())

	rows, err := query.Query()
	defer rows.Close()
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		var id string
		err := rows.Scan(&id)
		if err != nil {
			log.Fatal(err)
		}
		order_ids = append(order_ids, id)
	}

	return order_ids
}

func orders_custom_days_ids(delete_order_days int, db *sql.DB) []string {
	var order_ids []string

	query := sq.
		Select("id").
		From("orders").
		Where("updated_at < ? && (status = ? || status = ?)",
			time.Now().AddDate(0, 0, -delete_order_days).In(time_zone("Asia/Kolkata")).Format("2006-01-02 15:04:05"),
			"awaiting", "onhold").
		RunWith(db)

	log.Println(query.ToSql())

	rows, err := query.Query()
	defer rows.Close()
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		var id string
		err := rows.Scan(&id)
		if err != nil {
			log.Fatal(err)
		}
		order_ids = append(order_ids, id)
	}

	return order_ids
}

func removeDuplicates(a []string) []string {
	result := []string{}
	seen := map[string]string{}
	for _, val := range a {
		if _, ok := seen[val]; !ok {
			result = append(result, val)
			seen[val] = val
		}
	}
	return result
}

func delete_orders(order_ids []string, db *sql.DB) {
	for i, j := 0, len(order_ids); i < j; {
		tmp := j - i
		if tmp > 500 {
			tmp = i + 500
		} else {
			tmp += i
		}
		o_ids := order_ids[i:tmp]
		log.Println("Deleting Orders from ", i, "to", tmp)
		//Delete Items
		delete_items(o_ids, db)

		// Delete Order Data
		table_names := []string{"order_activities",
			"order_exceptions",
			"order_serials",
			"order_shippings"}

		for _, table_name := range table_names {
			query := sq.
				Delete(table_name).
				Where("order_id IN (" + strings.Join(o_ids, ",") + ")").
				RunWith(db)
			log.Println(query.ToSql())
			log.Println(query.Exec())
		}

		query := sq.
			Delete("orders").
			Where("id IN (" + strings.Join(o_ids, ",") + ")").
			RunWith(db)
		log.Println(query.ToSql())
		log.Println(query.Exec())
		i += 500
	}

	log.Println("Orders Deleted")
}

func delete_items(order_ids []string, db *sql.DB) {
	var order_item_ids []string

	if len(order_ids) == 0 {
		log.Println("No Order Found")
		return
	}

	query := sq.
		Select("id").
		From("order_items").
		Where("order_id IN (" + strings.Join(order_ids, ",") + ")").
		RunWith(db)
	log.Println(query.ToSql())

	rows, err := query.Query()
	defer rows.Close()
	if err != nil {
		log.Fatal(err)
	}

	for rows.Next() {
		var id string
		err := rows.Scan(&id)
		if err != nil {
			log.Fatal(err)
		}
		order_item_ids = append(order_item_ids, id)
	}

	if len(order_item_ids) == 0 {
		log.Println("No Order Items Found !!!")
		return
	}

	table_names := []string{"order_item_kit_products",
		"order_item_order_serial_product_lots",
		"order_item_scan_times"}

	for _, table_name := range table_names {
		query := sq.
			Delete(table_name).
			Where("order_item_id IN (" + strings.Join(order_item_ids, ",") + ")").
			RunWith(db)
		log.Println(query.ToSql())
		log.Println(query.Exec())
	}

	_query := sq.
		Delete("order_items").
		Where("id IN (" + strings.Join(order_item_ids, ",") + ")").
		RunWith(db)
	log.Println(_query.ToSql())
	log.Println(_query.Exec())
}