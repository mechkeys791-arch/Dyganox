import psycopg2
import sys

try:
    # Database connection parameters
    conn = psycopg2.connect(
        host="postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com",
        port=5432,
        database="postgres",
        user="postgres_ForPro",
        password="Promech0980"
    )
    
    # Create a cursor
    cur = conn.cursor()
    
    # Query to get all tables
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name;
    """)
    
    # Fetch all results
    tables = cur.fetchall()
    
    print(f"\nTotal tables found: {len(tables)}\n")
    print("=" * 50)
    print("Tables in database:")
    print("=" * 50)
    
    for table in tables:
        print(f"  - {table[0]}")
    
    print("=" * 50)
    
    # Close cursor and connection
    cur.close()
    conn.close()
    
except psycopg2.Error as e:
    print(f"Error connecting to database: {e}")
    sys.exit(1)
