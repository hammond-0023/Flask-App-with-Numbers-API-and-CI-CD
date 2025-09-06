from flask import Flask, request, jsonify
import redis
import psycopg2
import random

app = Flask(__name__)

# Redis connection
redis_client = redis.Redis(host='your-redis-endpoint', port=6379, db=0)

def get_number_facts(number):
    # Check cache first
    cached = redis_client.get(f"facts:{number}")
    if cached:
        return json.loads(cached)
    
    # Generate interesting facts
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
    
    # Cache the result
    redis_client.set(f"facts:{number}", json.dumps(facts))
    return facts

@app.route('/api/facts', methods=['POST'])
def handle_number():
    data = request.get_json()
    number = int(data.get('number'))
    facts = get_number_facts(number)
    return jsonify({'facts': facts})

if __name__ == '__main__':
    app.run(debug=True)