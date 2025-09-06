from flask import Flask, request, jsonify
import redis
import mysql.connector
import json
import os
from datetime import datetime

app = Flask("Numbers_App")

# Configuration from environment variables
REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_NAME = os.environ.get('DB_NAME', 'factsDB')

# Initialize Redis connection
redis_client = redis.Redis.from_url(REDIS_URL)

def get_db_connection():
    """Get a MySQL database connection"""
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

def get_number_facts(number):
    """Retrieve or generate number facts with caching"""
    # First check Redis cache
    cache_key = f"facts:{number}"
    cached = redis_client.get(cache_key)
    
    if cached:
        # Update last_accessed timestamp in MySQL
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            UPDATE number_facts 
            SET last_accessed = NOW() 
            WHERE number = %s
        """, (number,))
        conn.commit()
        return json.loads(cached)

    # Generate facts if not cached
    facts = [
        f"{number} is {'even' if number % 2 == 0 else 'odd'}",
        f"The square root of {number} is approximately {round(number ** 0.5, 2)}",
        f"The factorial of {number} is {'too large to calculate' if number > 20 else str(math.factorial(number))}",
        f"{number} in binary is {bin(number)[2:]}"
    ]
    
    # Add random interesting fact
    facts.append(random.choice([
        f"If you multiply {number} by itself {len(str(number))} times, you get {number ** len(str(number))}",
        f"The sum of all numbers from 1 to {number} is {(number * (number + 1)) // 2}",
        f"{number} degrees Celsius is equal to {((number * 9/5) + 32)} degrees Fahrenheit"
    ]))

    # Store in MySQL
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO number_facts (number, facts, created_at, last_accessed)
        VALUES (%s, %s, NOW(), NOW())
        ON CONFLICT (number) DO UPDATE 
        SET facts = EXCLUDED.facts, last_accessed = NOW()
    """, (number, json.dumps(facts)))
    conn.commit()

    # Cache in Redis with TTL of 24 hours
    redis_client.setex(cache_key, 86400, json.dumps(facts))
    return facts

@app.route('/api/facts', methods=['POST'])
def handle_number():
    data = request.get_json()
    number = int(data.get('number'))
    facts = get_number_facts(number)
    return jsonify({'facts': facts})

if __name__ == '__main__':
    app.run(debug=True)