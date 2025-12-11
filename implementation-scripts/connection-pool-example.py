#!/usr/bin/env python3
"""
Database Connection Pool Implementation for Latency Optimization
Supports both PostgreSQL and MySQL with connection pooling and retry logic
"""

import psycopg2
import psycopg2.pool
import pymysql
import pymysql.cursors
import time
import logging
from contextlib import contextmanager
from typing import Optional, Dict, Any
import threading
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DatabaseConnectionPool:
    """
    High-performance database connection pool with latency optimization
    """
    
    def __init__(self, db_config: Dict[str, Any]):
        self.db_config = db_config
        self.db_type = db_config.get('type', 'postgresql')
        self.pool = None
        self._lock = threading.Lock()
        self._initialize_pool()
    
    def _initialize_pool(self):
        """Initialize connection pool based on database type"""
        try:
            if self.db_type == 'postgresql':
                self._init_postgresql_pool()
            elif self.db_type == 'mysql':
                self._init_mysql_pool()
            else:
                raise ValueError(f"Unsupported database type: {self.db_type}")
            
            logger.info(f"Connection pool initialized for {self.db_type}")
        except Exception as e:
            logger.error(f"Failed to initialize connection pool: {e}")
            raise
    
    def _init_postgresql_pool(self):
        """Initialize PostgreSQL connection pool"""
        self.pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=self.db_config.get('min_connections', 5),
            maxconn=self.db_config.get('max_connections', 20),
            host=self.db_config['host'],
            port=self.db_config.get('port', 5432),
            database=self.db_config['database'],
            user=self.db_config['user'],
            password=self.db_config['password'],
            # Optimization parameters
            connect_timeout=self.db_config.get('connect_timeout', 5),
            application_name=self.db_config.get('app_name', 'latency-optimized-app'),
            # Connection pooling optimizations
            keepalives_idle=600,  # 10 minutes
            keepalives_interval=30,  # 30 seconds
            keepalives_count=3
        )
    
    def _init_mysql_pool(self):
        """Initialize MySQL connection pool (simplified implementation)"""
        # Note: pymysql doesn't have built-in pooling, this is a basic implementation
        self.pool_config = {
            'host': self.db_config['host'],
            'port': self.db_config.get('port', 3306),
            'user': self.db_config['user'],
            'password': self.db_config['password'],
            'database': self.db_config['database'],
            'charset': 'utf8mb4',
            'connect_timeout': self.db_config.get('connect_timeout', 5),
            'read_timeout': self.db_config.get('read_timeout', 30),
            'write_timeout': self.db_config.get('write_timeout', 30),
            'autocommit': True
        }
    
    @contextmanager
    def get_connection(self):
        """Get connection from pool with automatic cleanup"""
        connection = None
        start_time = time.time()
        
        try:
            if self.db_type == 'postgresql':
                connection = self.pool.getconn()
                if connection.closed:
                    # Connection is closed, get a new one
                    self.pool.putconn(connection, close=True)
                    connection = self.pool.getconn()
            elif self.db_type == 'mysql':
                connection = pymysql.connect(**self.pool_config)
            
            connection_time = (time.time() - start_time) * 1000
            logger.debug(f"Connection acquired in {connection_time:.2f}ms")
            
            yield connection
            
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            if connection and self.db_type == 'postgresql':
                # Mark connection as bad
                self.pool.putconn(connection, close=True)
                connection = None
            raise
        finally:
            if connection:
                if self.db_type == 'postgresql':
                    self.pool.putconn(connection)
                elif self.db_type == 'mysql':
                    connection.close()
    
    def execute_query(self, query: str, params: Optional[tuple] = None, fetch_results: bool = True):
        """Execute query with connection pooling and latency tracking"""
        start_time = time.time()
        
        with self.get_connection() as conn:
            try:
                cursor = conn.cursor()
                cursor.execute(query, params)
                
                if fetch_results:
                    results = cursor.fetchall()
                else:
                    results = cursor.rowcount
                
                if self.db_type == 'postgresql':
                    conn.commit()
                
                execution_time = (time.time() - start_time) * 1000
                logger.debug(f"Query executed in {execution_time:.2f}ms")
                
                return results
                
            except Exception as e:
                if self.db_type == 'postgresql':
                    conn.rollback()
                logger.error(f"Query execution error: {e}")
                raise
            finally:
                cursor.close()
    
    def health_check(self) -> bool:
        """Perform database health check"""
        try:
            if self.db_type == 'postgresql':
                result = self.execute_query("SELECT 1", fetch_results=True)
                return len(result) == 1
            elif self.db_type == 'mysql':
                result = self.execute_query("SELECT 1", fetch_results=True)
                return len(result) == 1
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return False
    
    def get_pool_status(self) -> Dict[str, Any]:
        """Get connection pool status"""
        if self.db_type == 'postgresql' and self.pool:
            with self._lock:
                return {
                    'min_connections': self.pool.minconn,
                    'max_connections': self.pool.maxconn,
                    'available_connections': len(self.pool._pool),
                    'used_connections': len(self.pool._used)
                }
        return {'status': 'Pool status not available for this database type'}
    
    def close_pool(self):
        """Close all connections in pool"""
        if self.pool and self.db_type == 'postgresql':
            self.pool.closeall()
            logger.info("Connection pool closed")

# Configuration examples
POSTGRESQL_CONFIG = {
    'type': 'postgresql',
    'host': os.getenv('DB_HOST', 'db-replica.us-east-1a.rds.amazonaws.com'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'appdb'),
    'user': os.getenv('DB_USER', 'dbuser'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'min_connections': 5,
    'max_connections': 20,
    'connect_timeout': 5,
    'app_name': 'latency-optimized-app'
}

MYSQL_CONFIG = {
    'type': 'mysql',
    'host': os.getenv('DB_HOST', 'db-replica.us-east-1a.rds.amazonaws.com'),
    'port': int(os.getenv('DB_PORT', '3306')),
    'database': os.getenv('DB_NAME', 'appdb'),
    'user': os.getenv('DB_USER', 'dbuser'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'connect_timeout': 5,
    'read_timeout': 30,
    'write_timeout': 30
}

# Usage example
def main():
    """Example usage of the connection pool"""
    
    # Initialize connection pool
    db_pool = DatabaseConnectionPool(POSTGRESQL_CONFIG)
    
    try:
        # Health check
        if db_pool.health_check():
            logger.info("Database connection healthy")
        
        # Example queries
        start_time = time.time()
        
        # Read query (use read replica)
        users = db_pool.execute_query(
            "SELECT id, username, email FROM users WHERE active = %s LIMIT 10",
            (True,)
        )
        
        read_time = (time.time() - start_time) * 1000
        logger.info(f"Read query completed in {read_time:.2f}ms, returned {len(users)} users")
        
        # Write query (use primary database)
        start_time = time.time()
        affected_rows = db_pool.execute_query(
            "UPDATE users SET last_login = NOW() WHERE id = %s",
            (1,),
            fetch_results=False
        )
        
        write_time = (time.time() - start_time) * 1000
        logger.info(f"Write query completed in {write_time:.2f}ms, affected {affected_rows} rows")
        
        # Pool status
        status = db_pool.get_pool_status()
        logger.info(f"Pool status: {status}")
        
    except Exception as e:
        logger.error(f"Application error: {e}")
    finally:
        db_pool.close_pool()

if __name__ == "__main__":
    main()
