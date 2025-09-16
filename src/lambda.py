import boto3
import redis
import mysql.connector
import json
from typing import Dict, Any

# Initialize Redis connection
redis_client = None

def get_redis_connection():
    global redis_client
    if redis_client is None:
        redis_client = redis.Redis(host='number-facts-cache.cache.t2.micro.eu-central-1.cache.amazonaws.com',
                                  port=6379,
                                  decode_responses=True)
    return redis_client

def get_db_connection():
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'hammond-db-instance'),
        user=os.environ.get('DB_USER', 'admin'),
        password=os.environ.get('DB_PASSWORD', ''),
        database=os.environ.get('DB_NAME', 'factsDB')
    )

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        # Extract number from path parameters
        number = int(event['pathParameters']['number'])
        
        # Try cache first
        redis_conn = get_redis_connection()
        cached_fact = redis_conn.get(f"fact:{number}")
        
        if cached_fact:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': True, 'fact': cached_fact})
            }
        
        # If not cached, fetch from database
        db = get_db_connection()
        cursor = db.cursor()
        
        query = "SELECT fact FROM facts WHERE number = %s"
        cursor.execute(query, (number,))
        
        result = cursor.fetchone()
        db.close()
        
        if result:
            fact = result[0]
            # Cache the result for future queries
            redis_conn.set(f"fact:{number}", fact, ex=3600)  # Cache for 1 hour
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'success': True, 'fact': fact})
            }
        
        return {
            'statusCode': 404,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': False, 'message': 'No fact found for this number'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': False, 'message': str(e)})
        }