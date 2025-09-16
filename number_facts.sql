CREATE TABLE IF NOT EXISTS facts (
  number INT PRIMARY KEY,
  fact VARCHAR(255) NOT NULL
);

INSERT INTO facts (number, fact) VALUES
(1, '1 is the first natural number.'),
(2, '2 is the only even prime number.'),
(3, '3 is the first odd prime number.'),
(4, '4 is the smallest composite number.'),
(5, '5 is the first odd prime greater than 2.'),
(6, '6 is the smallest perfect number.'),
(7, '7 is considered a lucky number in many cultures.'),
(8, '8 is the first cube greater than 1 (2^3).'),
(9, '9 is a square number (3^2).'),
(10, '10 is the base of our decimal system.'),
(11, '11 is the smallest two-digit prime.'),
(12, '12 is a dozen.'),
(13, '13 is considered unlucky by some, lucky by others.'),
(14, '14 is twice 7, a lucky double.'),
(15, '15 is a triangular number.'),
(16, '16 is a perfect square (4^2).'),
(17, '17 is a prime number.'),
(18, '18 is a multiple of 9.'),
(19, '19 is a prime number.'),
(20, '20 is a score (as in four score years).');