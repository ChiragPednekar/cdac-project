-- ==================================================================================
-- TATA SUPPLY CHAIN MANAGEMENT SYSTEM - COMPLETE DATABASE SCRIPT
-- Target DBMS: MySQL 8.0+
-- Project Context: Enterprise-wide Procurement, Inventory, Quality & Issuance Tracking
-- Execution Order: Independent reference tables -> Dependent transactional structures
-- ==================================================================================

DROP DATABASE IF EXISTS tata_supply_chain;
CREATE DATABASE tata_supply_chain;
USE tata_supply_chain;

-- ==================================================================================
-- PHASE 7: TABLE CREATION, RELATIONSHIPS, AND CONSTRAINTS
-- ==================================================================================

-- 1. Part_Category Table
CREATE TABLE Part_Category (
    category_id INT AUTO_INCREMENT,
    category_name VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    CONSTRAINT pk_part_category PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name UNIQUE (category_name)
) ENGINE=InnoDB;

-- 2. Payment_Terms Table
CREATE TABLE Payment_Terms (
    payment_term_id INT AUTO_INCREMENT,
    term_code VARCHAR(20) NOT NULL,
    description VARCHAR(255) NOT NULL,
    days_to_payment INT NOT NULL CHECK (days_to_payment >= 0),
    CONSTRAINT pk_payment_terms PRIMARY KEY (payment_term_id),
    CONSTRAINT uq_term_code UNIQUE (term_code)
) ENGINE=InnoDB;

-- 3. Parts Table
CREATE TABLE Parts (
    part_id INT AUTO_INCREMENT,
    part_number VARCHAR(30) NOT NULL,
    category_id INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL,
    unit_rate DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    opening_stock INT NOT NULL DEFAULT 0,
    current_stock INT NOT NULL DEFAULT 0,
    minimum_stock INT NOT NULL DEFAULT 0,
    order_quantity INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_parts PRIMARY KEY (part_id),
    CONSTRAINT uq_part_number UNIQUE (part_number),
    CONSTRAINT fk_parts_category FOREIGN KEY (category_id) REFERENCES Part_Category(category_id) ON UPDATE CASCADE,
    CONSTRAINT chk_unit_rate CHECK (unit_rate >= 0),
    CONSTRAINT chk_opening_stock CHECK (opening_stock >= 0),
    CONSTRAINT chk_current_stock CHECK (current_stock >= 0),
    CONSTRAINT chk_minimum_stock CHECK (minimum_stock >= 0),
    CONSTRAINT chk_order_qty CHECK (order_quantity >= 0)
) ENGINE=InnoDB;

-- 4. Vendors Table
CREATE TABLE Vendors (
    vendor_id INT AUTO_INCREMENT,
    vendor_code VARCHAR(20) NOT NULL,
    vendor_name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    payment_term_id INT NOT NULL,
    CONSTRAINT pk_vendors PRIMARY KEY (vendor_id),
    CONSTRAINT uq_vendor_code UNIQUE (vendor_code),
    CONSTRAINT fk_vendors_payment FOREIGN KEY (payment_term_id) REFERENCES Payment_Terms(payment_term_id) ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5. Vendor_Parts Table (Many-to-Many Breakdown between Vendors and Parts)
CREATE TABLE Vendor_Parts (
    vendor_id INT NOT NULL,
    part_id INT NOT NULL,
    supply_rate DECIMAL(12,2) NOT NULL,
    lead_time_days INT DEFAULT 7,
    CONSTRAINT pk_vendor_parts PRIMARY KEY (vendor_id, part_id),
    CONSTRAINT fk_vp_vendor FOREIGN KEY (vendor_id) REFERENCES Vendors(vendor_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vp_part FOREIGN KEY (part_id) REFERENCES Parts(part_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_supply_rate CHECK (supply_rate >= 0)
) ENGINE=InnoDB;

-- 6. Transporters Table
CREATE TABLE Transporters (
    transporter_id INT AUTO_INCREMENT,
    transporter_name VARCHAR(100) NOT NULL,
    contact_details VARCHAR(255) NOT NULL,
    license_number VARCHAR(50),
    CONSTRAINT pk_transporters PRIMARY KEY (transporter_id)
) ENGINE=InnoDB;

-- 7. Purchase_Order Table
CREATE TABLE Purchase_Order (
    po_id INT AUTO_INCREMENT,
    po_number VARCHAR(30) NOT NULL,
    vendor_id INT NOT NULL,
    po_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Open',
    total_amount DECIMAL(15,2) DEFAULT 0.00,
    CONSTRAINT pk_purchase_order PRIMARY KEY (po_id),
    CONSTRAINT uq_po_number UNIQUE (po_number),
    CONSTRAINT fk_po_vendor FOREIGN KEY (vendor_id) REFERENCES Vendors(vendor_id) ON UPDATE CASCADE,
    CONSTRAINT chk_po_status CHECK (status IN ('Open', 'Partially Received', 'Fulfilled', 'Cancelled'))
) ENGINE=InnoDB;

-- 8. Purchase_Order_Details Table
CREATE TABLE Purchase_Order_Details (
    po_detail_id INT AUTO_INCREMENT,
    po_id INT NOT NULL,
    part_id INT NOT NULL,
    order_qty INT NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    received_qty INT DEFAULT 0,
    CONSTRAINT pk_po_details PRIMARY KEY (po_detail_id),
    CONSTRAINT uq_po_part UNIQUE (po_id, part_id),
    CONSTRAINT fk_pod_po FOREIGN KEY (po_id) REFERENCES Purchase_Order(po_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pod_part FOREIGN KEY (part_id) REFERENCES Parts(part_id) ON UPDATE CASCADE,
    CONSTRAINT chk_order_qty_pod CHECK (order_qty > 0),
    CONSTRAINT chk_unit_price_pod CHECK (unit_price >= 0),
    CONSTRAINT chk_rcvd_qty_pod CHECK (received_qty >= 0)
) ENGINE=InnoDB;

-- 9. GRR Table (Goods Received Report)
CREATE TABLE GRR (
    grr_id INT AUTO_INCREMENT,
    grr_number VARCHAR(30) NOT NULL,
    challan_number VARCHAR(50) NOT NULL,
    challan_date DATE NOT NULL,
    po_id INT NOT NULL,
    transporter_id INT NOT NULL,
    received_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT,
    CONSTRAINT pk_grr PRIMARY KEY (grr_id),
    CONSTRAINT uq_grr_number UNIQUE (grr_number),
    CONSTRAINT fk_grr_po FOREIGN KEY (po_id) REFERENCES Purchase_Order(po_id) ON UPDATE CASCADE,
    CONSTRAINT fk_grr_transporter FOREIGN KEY (transporter_id) REFERENCES Transporters(transporter_id) ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10. GRR_Details Table
CREATE TABLE GRR_Details (
    grr_detail_id INT AUTO_INCREMENT,
    grr_id INT NOT NULL,
    part_id INT NOT NULL,
    challan_qty INT NOT NULL,
    received_qty INT NOT NULL,
    CONSTRAINT pk_grr_details PRIMARY KEY (grr_detail_id),
    CONSTRAINT uq_grr_part UNIQUE (grr_id, part_id),
    CONSTRAINT fk_grrd_grr FOREIGN KEY (grr_id) REFERENCES GRR(grr_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_grrd_part FOREIGN KEY (part_id) REFERENCES Parts(part_id) ON UPDATE CASCADE,
    CONSTRAINT chk_challan_qty CHECK (challan_qty > 0),
    CONSTRAINT chk_received_qty CHECK (received_qty >= 0)
) ENGINE=InnoDB;

-- 11. Inspection Table
CREATE TABLE Inspection (
    inspection_id INT AUTO_INCREMENT,
    grr_id INT NOT NULL,
    inspection_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    inspector_remarks TEXT,
    CONSTRAINT pk_inspection PRIMARY KEY (inspection_id),
    CONSTRAINT fk_inspection_grr FOREIGN KEY (grr_id) REFERENCES GRR(grr_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_insp_status CHECK (status IN ('Pending', 'Completed', 'Partial Failure'))
) ENGINE=InnoDB;

-- 12. Inspection_Details Table
CREATE TABLE Inspection_Details (
    inspection_detail_id INT AUTO_INCREMENT,
    inspection_id INT NOT NULL,
    part_id INT NOT NULL,
    accepted_qty INT NOT NULL DEFAULT 0,
    rejected_qty INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_inspection_details PRIMARY KEY (inspection_detail_id),
    CONSTRAINT uq_inspection_part UNIQUE (inspection_id, part_id),
    CONSTRAINT fk_id_inspection FOREIGN KEY (inspection_id) REFERENCES Inspection(inspection_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_id_part FOREIGN KEY (part_id) REFERENCES Parts(part_id) ON UPDATE CASCADE,
    CONSTRAINT chk_accepted_qty CHECK (accepted_qty >= 0),
    CONSTRAINT chk_rejected_qty CHECK (rejected_qty >= 0)
) ENGINE=InnoDB;

-- 13. MIR Table (Material Issue Requisition)
CREATE TABLE MIR (
    mir_id INT AUTO_INCREMENT,
    mir_number VARCHAR(30) NOT NULL,
    mir_date DATE NOT NULL,
    department_name VARCHAR(50) NOT NULL,
    requested_by VARCHAR(50),
    CONSTRAINT pk_mir PRIMARY KEY (mir_id),
    CONSTRAINT uq_mir_number UNIQUE (mir_number)
) ENGINE=InnoDB;

-- 14. MIR_Details Table
CREATE TABLE MIR_Details (
    mir_detail_id INT AUTO_INCREMENT,
    mir_id INT NOT NULL,
    part_id INT NOT NULL,
    quantity_issued INT NOT NULL,
    CONSTRAINT pk_mir_details PRIMARY KEY (mir_detail_id),
    CONSTRAINT uq_mir_part UNIQUE (mir_id, part_id),
    CONSTRAINT fk_mird_mir FOREIGN KEY (mir_id) REFERENCES MIR(mir_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mird_part FOREIGN KEY (part_id) REFERENCES Parts(part_id) ON UPDATE CASCADE,
    CONSTRAINT chk_quantity_issued CHECK (quantity_issued > 0)
) ENGINE=InnoDB;


-- ==================================================================================
-- PHASE 8: ENTERPRISE SEED DATA INJECTION (REALISTIC REPRESENTATION)
-- ==================================================================================

-- 10 Part Categories
INSERT INTO Part_Category (category_name, description) VALUES
('Raw Material Steel', 'Heavy manufacturing steel plates, bars, sheets'),
('Finished Engine Components', 'Fully machined components for engine blocks'),
('Fasteners', 'Industrial grade bolts, nuts, washers, rivets'),
('Electrical Modules', 'Wiring harnesses, sensory grids, microcontrollers'),
('Hydraulic Controls', 'High pressure fluids, valves, pistons, actuators'),
('Pneumatic Components', 'Compressed air lines, pressure valves, gauges'),
('Polymers & Plastics', 'Injection-molded outer dashboard casings'),
('Alloys & Casting', 'Unrefined mixed alloys for structural molding'),
('Gaskets & Seals', 'High temperature sealants, synthetic rubber lines'),
('Lubricants & Coolants', 'Chemical compound processing packs and engine cooling fluids');

-- 5 Payment Terms
INSERT INTO Payment_Terms (term_code, description, days_to_payment) VALUES
('NET30', 'Payment settling exactly 30 days post invoice tracking', 30),
('NET45', 'Payment settling 45 days post transaction confirmation', 45),
('NET60', 'Standard corporate credit framework 60 days clearance', 60),
('2/10NET30', '2% discount if settled in 10 days, else 30 days mandatory', 30),
('COD', 'Cash on Delivery execution parameters', 0);

-- 20 Parts Records (Sampling the 200 Raw Materials and 75 Finished Parts)
INSERT INTO Parts (part_number, category_id, description, unit_of_measure, unit_rate, opening_stock, current_stock, minimum_stock, order_quantity) VALUES
('TATA-RM-ST-001', 1, 'Grade-A Structural Carbon Steel Plate 10mm', 'KG', 45.50, 5000, 5000, 1500, 4000),
('TATA-RM-ST-002', 1, 'Stainless Steel Structural Rod 50mm Diameter', 'Meters', 120.00, 800, 800, 200, 600),
('TATA-FP-EN-101', 2, 'V8 Machined Engine Block Core Base Assembly', 'Nos', 12500.00, 50, 50, 15, 40),
('TATA-FP-EN-102', 2, 'Forged Balanced Crankshaft Component Assembly', 'Nos', 4200.00, 120, 120, 30, 80),
('TATA-FS-BL-201', 3, 'High-Tensile Hexagonal Flange M12 Bolt Pack 100', 'Boxes', 25.00, 400, 400, 100, 300),
('TATA-FS-NT-202', 3, 'Self-Locking Nylon Insert M12 Lock Nut Pack 100', 'Boxes', 18.50, 500, 500, 120, 400),
('TATA-EL-WH-301', 4, 'Main Cockpit Centralized Wiring Harness Grid', 'Nos', 3200.00, 90, 90, 25, 70),
('TATA-EL-SN-302', 4, 'Engine Thermal Precision Laser Sensor Unit', 'Nos', 450.00, 350, 350, 80, 250),
('TATA-HY-PV-401', 5, 'Heavy Duty Proportional Directional Control Valve', 'Nos', 1850.00, 60, 60, 15, 40),
('TATA-HY-CY-402', 5, 'Dual-Acting High Load Hydraulic Cylinder 200mm', 'Nos', 5400.00, 40, 40, 10, 30),
('TATA-PN-PR-501', 6, 'Digital Multi-Stage Air Pressure Controller Unit', 'Nos', 890.00, 110, 110, 30, 80),
('TATA-PL-DB-601', 7, 'Molded Dashboard High-Impact ABS Polymer Shell', 'Nos', 1650.00, 150, 150, 45, 120),
('TATA-AL-BR-701', 8, 'Phosphor Bronze Cast Bearing Material Block', 'KG', 180.00, 600, 600, 150, 500),
('TATA-GK-SL-801', 9, 'Synthetic Nitrile Rubber High Temp Engine Gasket', 'Nos', 75.00, 800, 800, 200, 600),
('TATA-LB-CL-901', 10, 'Premium Synthetic Heavy Engine Coolant Grade XL', 'Liters', 12.50, 4000, 4000, 1000, 3000),
('TATA-RM-ST-003', 1, 'Hot-Rolled High Strength Steel Strip Coils', 'Tons', 1450.00, 25, 25, 8, 20),
('TATA-FP-EN-103', 2, 'Precision Ground Dual Overhead Camshaft Shaft', 'Nos', 2800.00, 140, 140, 35, 100),
('TATA-EL-CU-303', 4, 'Main Powertrain Electronic Engine Control Unit (ECU)', 'Nos', 8500.00, 70, 70, 20, 50),
('TATA-PL-DR-602', 7, 'Reinforced Polymer Outer Left Passenger Door Trim', 'Nos', 920.00, 180, 180, 50, 130),
('TATA-LB-OL-902', 10, 'Industrial Grade High Viscosity Gear Box Lubricant', 'Liters', 22.00, 2500, 2500, 600, 1800);

-- 10 Vendors
INSERT INTO Vendors (vendor_code, vendor_name, address, payment_term_id) VALUES
('VND-TATA-001', 'Tata Steel Ltd. Processing Plant Division', 'Jamshedpur Industrial Zone, Jharkhand, India', 1),
('VND-BHARAT-002', 'Bharat Heavy Electricals & Castings Co.', 'BHEL Enclave, Bhopal, Madhya Pradesh, India', 2),
('VND-AMTEK-003', 'Amtek Auto Precision Components Group', 'Manesar Automotive Manufacturing Belt, Haryana, India', 1),
('VND-LUCAS-004', 'Lucas-TVS Electrical Solutions Ltd.', 'Padi Industrial Complex, Chennai, Tamil Nadu, India', 3),
('VND-WIPRO-005', 'Wipro Infrastructure Engineering Hydraulics', 'Peenya Industrial Area, Bangalore, Karnataka, India', 1),
('VND-SUPREME-006', 'Supreme Polymers & Injection Molders', 'GIDC Industrial Estate, Pune, Maharashtra, India', 4),
('VND-BOSCH-007', 'Bosch Automotive Powertrain Systems India', 'Electronic City Phase II, Bangalore, Karnataka, India', 1),
('VND-SKF-008', 'SKF Bearings & Industrial Seals Corp', 'Chinchwad Industrial Belt, Pune, Maharashtra, India', 2),
('VND-CASTROL-009', 'Castrol Industrial Lubricants Division', 'Patalganga Plant, Raigad, Maharashtra, India', 3),
('VND-FAST-010', 'Universal Fasteners & Hardware Systems', 'Ludhiyana Production Cluster, Punjab, India', 5);

-- Map Vendor Parts Rates
INSERT INTO Vendor_Parts (vendor_id, part_id, supply_rate) VALUES
(1, 1, 44.00), (1, 2, 118.00), (1, 16, 1420.00),
(2, 3, 12300.00), (2, 13, 175.00), (3, 4, 4100.00),
(3, 17, 2750.00), (4, 7, 3150.00), (4, 8, 440.00),
(5, 9, 1800.00), (5, 10, 5300.00), (6, 12, 1600.00),
(6, 19, 900.00), (7, 18, 8400.00), (8, 14, 72.00),
(9, 15, 12.00), (9, 20, 21.00), (10, 5, 24.00),
(10, 6, 18.00);

-- 10 Transporters
INSERT INTO Transporters (transporter_name, contact_details, license_number) VALUES
('TCI Freight Logistics', 'Mumbai HQ Office - contact@tci.com - 022-25413698', 'MUM-TX-74125'),
('Gati Kausar Cold & Supply Chains', 'Delhi Hub Center - info@gatikau.com - 011-41253698', 'DL-TX-85214'),
('VRL Logistics Enterprise', 'Bangalore Central - operations@vrl.com - 080-23654125', 'BLR-TX-96325'),
('Blue Dart Surface Cargo', 'Chennai Airport Belt - cargo@bluedart.com - 044-22365874', 'CHN-TX-14785'),
('SafeXpress Supply Chain Architects', 'Kolkata Depot Area - safe@safex.com - 033-26541258', 'KOL-TX-25896'),
('Mahindra Logistics Division', 'Pune Chakan Station - corporate@mahindra.com - 020-27415896', 'PNE-TX-36914'),
('Transport Corp of India Enterprise', 'Hyderabad Hub - hyd@tci.com - 040-23651478', 'HYD-TX-47821'),
('AllCargo Logistics Group', 'Nhava Sheva Port Zone - shipping@allcargo.com - 022-27845126', 'NS-TX-58963'),
('Container Corp of India (CONCOR)', 'New Delhi Rail Yard - support@concor.com - 011-23456789', 'DL-TX-69854'),
('DTDC Supply Chain Solutions', 'Ahmedabad Branch - tracks@dtdc.com - 079-26587412', 'AMD-TX-78965');

-- 15 Purchase Orders
INSERT INTO Purchase_Order (po_number, vendor_id, po_date, status, total_amount) VALUES
('PO-2026-001', 1, '2026-05-01', 'Fulfilled', 176000.00),
('PO-2026-002', 1, '2026-05-02', 'Fulfilled', 70800.00),
('PO-2026-003', 2, '2026-05-04', 'Fulfilled', 492000.00),
('PO-2026-004', 3, '2026-05-05', 'Fulfilled', 328000.00),
('PO-2026-005', 10, '2026-05-06', 'Fulfilled', 7200.00),
('PO-2026-006', 10, '2026-05-08', 'Fulfilled', 7200.00),
('PO-2026-007', 4, '2026-05-10', 'Fulfilled', 220500.00),
('PO-2026-008', 4, '2026-05-12', 'Fulfilled', 110000.00),
('PO-2026-009', 5, '2026-05-14', 'Fulfilled', 72000.00),
('PO-2026-010', 5, '2026-05-15', 'Fulfilled', 159000.00),
('PO-2026-011', 6, '2026-05-18', 'Fulfilled', 192000.00),
('PO-2026-012', 7, '2026-05-20', 'Fulfilled', 420000.00),
('PO-2026-013', 8, '2026-05-22', 'Fulfilled', 43200.00),
('PO-2026-014', 9, '2026-05-24', 'Fulfilled', 36000.00),
('PO-2026-015', 9, '2026-05-25', 'Open', 37800.00);

-- Purchase Order Details Line Items
INSERT INTO Purchase_Order_Details (po_id, part_id, order_qty, unit_price, received_qty) VALUES
(1, 1, 4000, 44.00, 4000),
(2, 2, 600, 118.00, 600),
(3, 3, 40, 12300.00, 40),
(4, 4, 80, 4100.00, 80),
(5, 5, 300, 24.00, 300),
(6, 6, 400, 18.00, 400),
(7, 7, 70, 3150.00, 70),
(8, 8, 250, 440.00, 250),
(9, 9, 40, 1800.00, 40),
(10, 10, 30, 5300.00, 30),
(11, 12, 120, 1600.00, 120),
(12, 18, 50, 8400.00, 50),
(13, 14, 600, 72.00, 600),
(14, 15, 3000, 12.00, 3000),
(15, 20, 1800, 21.00, 0);

-- 20 GRR Records
INSERT INTO GRR (grr_number, challan_number, challan_date, po_id, transporter_id, remarks) VALUES
('GRR-2026-001', 'CH-98541', '2026-05-04', 1, 1, 'Bulk steel plate shipment received fine'),
('GRR-2026-002', 'CH-98542', '2026-05-05', 2, 1, 'Steel rods safely delivered on flatbed'),
('GRR-2026-003', 'CH-14258', '2026-05-08', 3, 3, 'Engine blocks received crate structural check OK'),
('GRR-2026-004', 'CH-36521', '2026-05-09', 4, 3, 'Cankshafts delivered under dynamic seals'),
('GRR-2026-005', 'CH-47852', '2026-05-10', 5, 6, 'Fastener boxes received sealed'),
('GRR-2026-006', 'CH-47853', '2026-05-12', 6, 6, 'Nylon lock nuts arrived yard 3'),
('GRR-2026-007', 'CH-25896', '2026-05-15', 7, 4, 'Wiring harnesses structural pallet check passed'),
('GRR-2026-008', 'CH-25897', '2026-05-16', 8, 4, 'Thermal sensors high-precision packing verified'),
('GRR-2026-009', 'CH-36914', '2026-05-18', 9, 2, 'Directional valves standard delivery'),
('GRR-2026-010', 'CH-36915', '2026-05-19', 10, 2, 'Hydraulic cylinders massive structural frame delivery'),
('GRR-2026-011', 'CH-14789', '2026-05-22', 11, 5, 'ABS Polymer dashboard units incoming'),
('GRR-2026-012', 'CH-96325', '2026-05-24', 12, 7, 'ECU High value crates secure dispatch'),
('GRR-2026-013', 'CH-85214', '2026-05-26', 13, 8, 'Engine gaskets box delivery standard'),
('GRR-2026-014', 'CH-74125', '2026-05-28', 14, 9, 'Coolant tankers fluid standard sampling initiated'),
('GRR-2026-015', 'CH-74126', '2026-05-29', 1, 1, 'Additional partial logistics check line'),
('GRR-2026-016', 'CH-74127', '2026-05-30', 2, 2, 'Validation logging line 2'),
('GRR-2026-017', 'CH-74128', '2026-05-31', 3, 3, 'Validation logging line 3'),
('GRR-2026-018', 'CH-74129', '2026-06-01', 4, 4, 'Validation logging line 4'),
('GRR-2026-019', 'CH-74130', '2026-06-02', 5, 5, 'Validation logging line 5'),
('GRR-2026-020', 'CH-74131', '2026-06-03', 6, 6, 'Validation logging line 6');

-- GRR Details Data Mapping
INSERT INTO GRR_Details (grr_id, part_id, challan_qty, received_qty) VALUES
(1, 1, 4000, 4000), (2, 2, 600, 600), (3, 3, 40, 40), (4, 4, 80, 80),
(5, 5, 300, 300), (6, 6, 400, 400), (7, 7, 70, 70), (8, 8, 250, 250),
(9, 9, 40, 40), (10, 10, 30, 30), (11, 12, 120, 120), (12, 18, 50, 50),
(13, 14, 600, 600), (14, 15, 3000, 3000), (15, 1, 100, 100), (16, 2, 20, 20),
(17, 3, 5, 5), (18, 4, 10, 10), (19, 5, 50, 50), (20, 6, 50, 50);

-- 20 Inspection Records
INSERT INTO Inspection (grr_id, inspection_date, status, inspector_remarks) VALUES
(1, '2026-05-05', 'Completed', 'Thickness checks perfectly within tolerance. Accepted all.'),
(2, '2026-05-06', 'Completed', 'Surface finishing clean. No scoring detected.'),
(3, '2026-05-09', 'Partial Failure', '2 Engine Blocks found with microscopic fissure casting defects. Rejected 2.'),
(4, '2026-05-10', 'Completed', 'Dynamic balancing metrics fully verified.'),
(5, '2026-05-11', 'Completed', 'Thread pitch dimensions compliant.'),
(6, '2026-05-13', 'Completed', 'Nylon ring locking elasticity verified.'),
(7, '2026-05-16', 'Completed', 'Continuity testing across all loops completely secure.'),
(8, '2026-05-17', 'Completed', 'Laser calibration response timing checked.'),
(9, '2026-05-19', 'Completed', 'Pressure holding metrics fully verified.'),
(10, '2026-05-20', 'Completed', 'Sealing configuration holding up perfectly under high load.'),
(11, '2026-05-23', 'Completed', 'Polymer elasticity molding checks pass.'),
(12, '2026-05-25', 'Completed', 'Firmware checksum validated on specialized flash grid.'),
(13, '2026-05-27', 'Completed', 'High temperature structural compression passed.'),
(14, '2026-05-29', 'Completed', 'Chemical composition analysis confirmed pure.'),
(15, '2026-05-30', 'Completed', 'Batch processing trace check pass.'),
(16, '2026-05-31', 'Completed', 'Batch processing trace check pass.'),
(17, '2026-06-01', 'Completed', 'Batch processing trace check pass.'),
(18, '2026-06-02', 'Completed', 'Batch processing trace check pass.'),
(19, '2026-06-03', 'Completed', 'Batch processing trace check pass.'),
(20, '2026-06-04', 'Completed', 'Batch processing trace check pass.');

-- Inspection Details Line Quantities
INSERT INTO Inspection_Details (inspection_id, part_id, accepted_qty, rejected_qty) VALUES
(1, 1, 4000, 0), (2, 2, 600, 0), (3, 3, 38, 2), (4, 4, 80, 0),
(5, 5, 300, 0), (6, 6, 400, 0), (7, 7, 70, 0), (8, 8, 250, 0),
(9, 9, 40, 0), (10, 10, 30, 0), (11, 12, 120, 0), (12, 18, 50, 0),
(13, 14, 600, 0), (14, 15, 3000, 0), (15, 1, 100, 0), (16, 2, 20, 0),
(17, 3, 5, 0), (18, 4, 10, 0), (19, 5, 50, 0), (20, 6, 50, 0);

-- Update stock values to match successful initial receipts minus zero initial issues
UPDATE Parts SET current_stock = opening_stock + 4000 WHERE part_id = 1;
UPDATE Parts SET current_stock = opening_stock + 600 WHERE part_id = 2;
UPDATE Parts SET current_stock = opening_stock + 38 WHERE part_id = 3;
UPDATE Parts SET current_stock = opening_stock + 80 WHERE part_id = 4;
UPDATE Parts SET current_stock = opening_stock + 300 WHERE part_id = 5;
UPDATE Parts SET current_stock = opening_stock + 400 WHERE part_id = 6;
UPDATE Parts SET current_stock = opening_stock + 70 WHERE part_id = 7;
UPDATE Parts SET current_stock = opening_stock + 250 WHERE part_id = 8;
UPDATE Parts SET current_stock = opening_stock + 40 WHERE part_id = 9;
UPDATE Parts SET current_stock = opening_stock + 30 WHERE part_id = 10;
UPDATE Parts SET current_stock = opening_stock + 120 WHERE part_id = 12;
UPDATE Parts SET current_stock = opening_stock + 50 WHERE part_id = 18;
UPDATE Parts SET current_stock = opening_stock + 600 WHERE part_id = 14;
UPDATE Parts SET current_stock = opening_stock + 3000 WHERE part_id = 15;

-- 20 MIR Records (Plant Store Issues)
INSERT INTO MIR (mir_number, mir_date, department_name, requested_by) VALUES
('MIR-2026-001', '2026-05-10', 'Heavy Weld Shop Floor Line A', 'A. K. Sharma'),
('MIR-2026-002', '2026-05-12', 'Engine Machining Cell 3', 'R. Deshmukh'),
('MIR-2026-003', '2026-05-14', 'Engine Block Main Assembly Line', 'S. Narayanan'),
('MIR-2026-004', '2026-05-15', 'Main Assembly Line B', 'S. Narayanan'),
('MIR-2026-005', '2026-05-16', 'Chassis Integration Unit', 'John Miller'),
('MIR-2026-006', '2026-05-18', 'Chassis Integration Unit', 'John Miller'),
('MIR-2026-007', '2026-05-20', 'Electronics Integration Bay', 'M. Flynn'),
('MIR-2026-008', '2026-05-22', 'Electronics Integration Bay', 'M. Flynn'),
('MIR-2026-009', '2026-05-24', 'Hydraulic Fitting Section', 'V. Prasad'),
('MIR-2026-010', '2026-05-25', 'Hydraulic Fitting Section', 'V. Prasad'),
('MIR-2026-011', '2026-05-26', 'Trim & Interior Assembly Cell', 'G. Western'),
('MIR-2026-012', '2026-05-28', 'Powertrain Calibration Deck', 'Dr. R. Kapoor'),
('MIR-2026-013', '2026-05-30', 'Main Assembly Line B', 'S. Narayanan'),
('MIR-2026-014', '2026-06-01', 'Fluid Ingress Testing Pad', 'A. Vignesh'),
('MIR-2026-015', '2026-06-02', 'Heavy Weld Shop Floor Line A', 'A. K. Sharma'),
('MIR-2026-016', '2026-06-03', 'Engine Machining Cell 3', 'R. Deshmukh'),
('MIR-2026-017', '2026-06-04', 'Engine Block Main Assembly Line', 'S. Narayanan'),
('MIR-2026-018', '2026-06-05', 'Main Assembly Line B', 'S. Narayanan'),
('MIR-2026-019', '2026-06-06', 'Chassis Integration Unit', 'John Miller'),
('MIR-2026-020', '2026-06-07', 'Electronics Integration Bay', 'M. Flynn');

-- MIR Line Items Allocation mapping (This triggers stock depletion simulation)
INSERT INTO MIR_Details (mir_id, part_id, quantity_issued) VALUES
(1, 1, 1500), (2, 2, 200), (3, 3, 10), (4, 4, 30),
(5, 5, 150), (6, 6, 200), (7, 7, 30), (8, 8, 100),
(9, 9, 15), (10, 10, 10), (11, 12, 50), (12, 18, 15),
(13, 14, 250), (14, 15, 1200), (15, 1, 200), (16, 2, 50),
(17, 3, 5), (18, 4, 10), (19, 5, 20), (20, 7, 10);

-- Apply corresponding stock depletions manually to reflect perfect transactional trace
UPDATE Parts SET current_stock = current_stock - 1500 WHERE part_id = 1;
UPDATE Parts SET current_stock = current_stock - 200 WHERE part_id = 2;
UPDATE Parts SET current_stock = current_stock - 10 WHERE part_id = 3;
UPDATE Parts SET current_stock = current_stock - 30 WHERE part_id = 4;
UPDATE Parts SET current_stock = current_stock - 150 WHERE part_id = 5;
UPDATE Parts SET current_stock = current_stock - 200 WHERE part_id = 6;
UPDATE Parts SET current_stock = current_stock - 30 WHERE part_id = 7;
UPDATE Parts SET current_stock = current_stock - 100 WHERE part_id = 8;
UPDATE Parts SET current_stock = current_stock - 15 WHERE part_id = 9;
UPDATE Parts SET current_stock = current_stock - 10 WHERE part_id = 10;
UPDATE Parts SET current_stock = current_stock - 50 WHERE part_id = 12;
UPDATE Parts SET current_stock = current_stock - 15 WHERE part_id = 18;
UPDATE Parts SET current_stock = current_stock - 250 WHERE part_id = 14;
UPDATE Parts SET current_stock = current_stock - 1200 WHERE part_id = 15;
UPDATE Parts SET current_stock = current_stock - 200 WHERE part_id = 1;
UPDATE Parts SET current_stock = current_stock - 50 WHERE part_id = 2;
UPDATE Parts SET current_stock = current_stock - 5 WHERE part_id = 3;
UPDATE Parts SET current_stock = current_stock - 10 WHERE part_id = 4;
UPDATE Parts SET current_stock = current_stock - 20 WHERE part_id = 5;
UPDATE Parts SET current_stock = current_stock - 10 WHERE part_id = 7;


-- ==================================================================================
-- PHASE 10: DATABASE OBJECTS (VIEWS, STORED PROCEDURES, AND TRIGGERS)
-- ==================================================================================

-- 1. Views
CREATE OR REPLACE VIEW Inventory_View AS
SELECT 
    p.part_id,
    p.part_number,
    c.category_name,
    p.description,
    p.unit_of_measure,
    p.opening_stock,
    p.current_stock,
    p.minimum_stock,
    p.unit_rate,
    (p.current_stock * p.unit_rate) AS stock_valuation,
    CASE 
        WHEN p.current_stock <= p.minimum_stock THEN 'CRITICAL REORDER'
        ELSE 'OPTIMAL'
    END AS stock_status
FROM Parts p
JOIN Part_Category c ON p.category_id = c.category_id;

CREATE OR REPLACE VIEW Vendor_Supply_View AS
SELECT 
    v.vendor_id,
    v.vendor_code,
    v.vendor_name,
    p.part_number,
    p.description AS part_description,
    vp.supply_rate
FROM Vendors v
JOIN Vendor_Parts vp ON v.vendor_id = vp.vendor_id
JOIN Parts p ON vp.part_id = p.part_id;

CREATE OR REPLACE VIEW Inspection_View AS
SELECT 
    i.inspection_id,
    g.grr_number,
    p.part_number,
    id.accepted_qty,
    id.rejected_qty,
    i.inspection_date,
    i.status AS qa_status,
    i.inspector_remarks
FROM Inspection i
JOIN GRR g ON i.grr_id = g.grr_id
JOIN Inspection_Details id ON i.inspection_id = id.inspection_id
JOIN Parts p ON id.part_id = p.part_id;

-- 2. Stored Procedures
DELIMITER $$

CREATE PROCEDURE Generate_GRR(
    IN p_challan_num VARCHAR(50),
    IN p_challan_date DATE,
    IN p_po_id INT,
    IN p_transporter_id INT,
    IN p_remarks TEXT,
    OUT out_grr_num VARCHAR(30)
)
BEGIN
    DECLARE v_next_id INT;
    SELECT IFNULL(MAX(grr_id), 0) + 1 INTO v_next_id FROM GRR;
    SET out_grr_num = CONCAT('GRR-', YEAR(CURDATE()), '-', LPAD(v_next_id, 4, '0'));
    
    INSERT INTO GRR (grr_number, challan_number, challan_date, po_id, transporter_id, remarks)
    VALUES (out_grr_num, p_challan_num, p_challan_date, p_po_id, p_transporter_id, p_remarks);
END$$

CREATE PROCEDURE Generate_MIR(
    IN p_dept_name VARCHAR(50),
    IN p_req_by VARCHAR(50),
    OUT out_mir_num VARCHAR(30)
)
BEGIN
    DECLARE v_next_id INT;
    SELECT IFNULL(MAX(mir_id), 0) + 1 INTO v_next_id FROM MIR;
    SET out_mir_num = CONCAT('MIR-', YEAR(CURDATE()), '-', LPAD(v_next_id, 4, '0'));
    
    INSERT INTO MIR (mir_number, mir_date, department_name, requested_by)
    VALUES (out_mir_num, CURDATE(), p_dept_name, p_req_by);
END$$

DELIMITER ;

-- 3. Triggers for Dynamic Inventory Control Flow
DELIMITER $$

CREATE TRIGGER trg_after_inspection_insert
AFTER INSERT ON Inspection_Details
FOR EACH ROW
BEGIN
    -- Increase warehouse physical stock dynamically upon successful quality acceptance criteria match
    UPDATE Parts 
    SET current_stock = current_stock + NEW.accepted_qty
    WHERE part_id = NEW.part_id;
END$$

CREATE TRIGGER trg_after_mir_insert
AFTER INSERT ON MIR_Details
FOR EACH ROW
BEGIN
    -- Deplete inventory immediately when material is successfully requisitioned by production floor lines
    UPDATE Parts 
    SET current_stock = current_stock - NEW.quantity_issued
    WHERE part_id = NEW.part_id;
END$$

DELIMITER ;

-- 4. Enterprise Indexes for Performance Tuning
CREATE INDEX idx_parts_number ON Parts(part_number);
CREATE INDEX idx_vendors_code ON Vendors(vendor_code);
CREATE INDEX idx_po_number ON Purchase_Order(po_number);
CREATE INDEX idx_grr_number ON GRR(grr_number);
CREATE INDEX idx_mir_number ON MIR(mir_number);
