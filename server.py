from fastmcp import FastMCP
import httpx
from dotenv import load_dotenv

load_dotenv()

mcp = FastMCP("PostgREST Customer MCP Server")

POSTGREST_URL = "http://localhost:3000/"

CUSTOMER_DOMAIN = "customers"
ORDER_DOMAIN = "orders"


@mcp.tool()
async def get_all_customers(limit: int = 5, offset: int = 0):
    """
    search all customers from the database.
    :param limit: The maximum number of customers to return (default: 5).
    :param offset: The number of rows to skip for pagination (default: 0).
    :return: a list of all customers
    """
    params = {
        "limit": limit,
        "offset":offset,
        "select": "*,customer_pii(*)"
    }
    # Implementation for fetching customer info
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(POSTGREST_URL+CUSTOMER_DOMAIN, params=params, timeout=10)

            # Raise an exception for non-2xx responses
            response.raise_for_status()

            data = response.json()

            if not data:
                print("No customer data found in the database")
                return {"status": "FAILED", "data": []}

        except httpx.HTTPStatusError as e:
            print(f"API Error: Failed to fetch customer data. Status code: {e.response.status_code}")
            return {"status": "FAILED", "data": []}

        except httpx.RequestError as e:
            print(f"API Error: Could not connect to PostgREST at {POSTGREST_URL+CUSTOMER_DOMAIN}")
            return {"status": "FAILED", "data": []}
    print(f"Customers: {data}")
    return {"status": "SUCCESS", "data": data}

@mcp.tool()
async def get_customer_by_id(customer_id: str, limit: int = 5, offset: int = 0):
    """
    Search customer by id
    :param limit: The maximum number of customers to return (default: 5).
    :param offset: The number of rows to skip for pagination (default: 0).
    :param customer_id: The ID of the customer to retrieve.
    :return: customer with the customer ID.
    """

    params = {
        "limit": limit,
        "offset": offset,
        "customer_id": f"eq.{customer_id}",
        "select": "*,customer_pii(*)",
    }

    # Implementation for fetching customer info with customer id
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(POSTGREST_URL+CUSTOMER_DOMAIN, params=params, timeout=10)

            # Raise an exception for non-2xx responses
            response.raise_for_status()

            data = response.json()

        except httpx.HTTPStatusError as e:
            print(f"API Error: Failed to fetch customer data with id {customer_id}. Status code: {e.response.status_code}")
            return {"status": "FAILED", "data": []}

        except httpx.RequestError as e:
            print(f"API Error: Could not connect to PostgREST at {POSTGREST_URL+CUSTOMER_DOMAIN}")
            return {"status": "FAILED", "data": []}

    print(f"Customer: {data}")
    return {"status": "SUCCESS", "data": data}

@mcp.tool()
async def get_order_by_id(order_id: str, limit: int = 5, offset: int = 0):
    """
    Search order by order id
    :param limit: The maximum number of customers to return (default: 5).
    :param offset: The number of rows to skip for pagination (default: 0).
    :param order_id: The ID of the order to retrieve.
    :return: order with the order ID.
    """

    params = {
        "limit": limit,
        "offset": offset,
        "order_id" :f"eq.{order_id}"
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(POSTGREST_URL+ORDER_DOMAIN, params=params, timeout=10)

            response.raise_for_status()
            data = response.json()

        except httpx.HTTPStatusError as e:
            print(f"API Error: Failed to fetch order data with id {order_id}. Status code: {e.response.status_code}")
            return {"status": "FAILED", "data": []}

        except httpx.RequestError as e:
            print(f"API Error: Could not connect to PostgREST at {POSTGREST_URL+ORDER_DOMAIN}")
            return {"status": "FAILED", "data": []}

    print(f"Order data: {data}")
    return {"status" : "SUCCESS", "data" : data }

@mcp.tool()
async def get_orders_by_customer_id(customer_id: str, limit: int = 5, offset: int = 0):
    """
    Search the order list by customer id
    :param limit: The maximum number of customers to return (default: 5).
    :param offset: The number of rows to skip for pagination (default: 0).
    :param customer_id: The ID of the customer whose orders to retrieve.
    :return: List of orders for the specified customer.
    """

    params = {
        "limit" : limit,
        "offset" : offset,
        "customer_id" : customer_id
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(POSTGREST_URL+ORDER_DOMAIN, params = params, timeout = 10)

            response.raise_for_status()

            data = response.json()

        except httpx.HTTPStatusError as e:
            print(f"API Error: Failed to fetch order data with id {customer_id}. Status code: {e.response.status_code}")
            return {"status": "FAILED", "data": []}

        except httpx.RequestError as e:
            print(f"API Error: Could not connect to PostgREST at {POSTGREST_URL+ORDER_DOMAIN}")
            return {"status": "FAILED", "data": []}

    print(f"Orders by customer {customer_id}: {data}")
    return {"status": "SUCCESS", "data": data}

@mcp.tool()
async def get_all_orders(limit: int = 5, offset: int = 0):
    """
    Search all orders
    :param limit: The maximum number of orders to return (default: 5).
    :param offset: The number of rows to skip for pagination (default: 0).
    :return: List of orders.
    """
    params = {
        "limit": limit,
        "offset": offset
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(POSTGREST_URL+ORDER_DOMAIN, params = params, timeout = 10)
            response.raise_for_status()

            data = response.json()

        except httpx.HTTPStatusError as e:
            print(f"API Error: Failed to fetch orders. Status code: {e.response.status_code}")
            return {"status": "FAILED", "data": []}

        except httpx.RequestError as e:
            print(f"API Error: Could not connect to PostgREST at {POSTGREST_URL+ORDER_DOMAIN}")
            return {"status": "FAILED", "data": []}

    return {"status": "SUCCESS", "data": data}


if __name__ == "__main__":
    print("Correctly configured PostgREST Customer MCP Server is running.")
    # mcp.run(transport="stdio")
    mcp.run(
        # transport="sse",
        # host="127.0.0.1",  # Binds only to your localhost loopback
        # port=8000,         # Choose an open port
    )


