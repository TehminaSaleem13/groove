# Order Scan

#input is barcode which is increment_id in the orders table

Example

`GET /scan_pack/scan_order_by_barcode`

`Each barcode scan will check the status and provide you with associated next_state. Based on this the client can `
` select which state it uses next `

```js

```


## Reading a single report

You can `GET` the URL of a report to retrieve it individually.

Example

`GET <URL>`
```json
{
  "url": "...",
  "yesterday_url": "...",
  "tomorrow_url": "...",
  "earlier_mealtime_url": "...", // May be null
  "later_mealtime_url": "...", // May be null
  "previous_child_url": "...", // May be null
  "next_child_url": "...", // May be null
  "item": {
    // The normal eating report attributes
    // ...
  }
}
```


## Saving eating reports

You can save eating reports by `PUT`ting them to their `url`.

Example

`PUT <the-report's-url>`

Request-Body:
```js
{
  "url": "...",
  "date": "2013-10-24",
  "mealtime": "lunch",
  "child": {
    "name": "Rich Hickey",
    "picture_url": "..."
  },
  "foods": [
    { // The child has eaten the rest of it's steak and even a second serving
      "type": {
        "id": 123,
        "name": "Steak"
      },
      "unit": {
        "name": "mouthfuls"
      },
      "assigned_quantity": 10,
      "eaten_percentage": 14
    },
    { // It has drunken 4 sips
      "type": {
        "id": 123,
        "name": "Water"
      },
      "unit": {
        "name": "sips"
      },
      "assigned_quantity": 5,
      "eaten_percentage": 4
    }
  ]
}
```
