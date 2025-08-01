// lib/screens/organization/add_employee_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import the newly created custom table cell widget
import 'widgets/custom_table_cell.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> organizationData;

  const AddEmployeeScreen({
    super.key,
    required this.organizationData,
  });

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  bool _isAddingEmployee = false;

  // Fixed controller naming to match their actual usage
  final TextEditingController _lastNameController = TextEditingController(); // Овог (Last name)
  final TextEditingController _firstNameController = TextEditingController(); // Нэр (First name)
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _employeeEmailController = TextEditingController();
  final TextEditingController _registrationNumberController = TextEditingController(); // Added for registration number
  final TextEditingController _salaryController = TextEditingController(); // Added for monthly salary
  String? _selectedStatus;

  // Status options for the dropdown, based on the image
  final List<String> _statusOptions = [
    'Идэвхтэй ажилтан',
    'Түршсэн ажилтан',
    'Жирэмсний амралттай',
    'Ажлаас гарсан',
    'Цагийн ажилтан',
    'Гэрээт ажилтан',
    'Дадлагын ажилтан',
    'Сул зогсолт',
    'Уртaн амралт'
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('AddEmployeeScreen initialized with organization data: ${widget.organizationData}');
    _fetchEmployees();
  }

  // Fetches employees from Firestore
  void _fetchEmployees() {
    final user = _auth.currentUser;
    
    if (user == null) {
      debugPrint('Cannot fetch employees - no authenticated user');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // The organization ID should be the user's UID since organizations are stored with their creator's UID
    String organizationId = user.uid;
    
    debugPrint('Fetching employees for organization ID: $organizationId');

    // Listen for real-time updates to the 'employees' subcollection
    _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('employees')
        .snapshots()
        .listen((snapshot) {
      final employees = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID for potential future use
        return data;
      }).toList();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    }, onError: (error) {
      // Handle any errors
      debugPrint("Error fetching employees: $error");
      setState(() {
        _isLoading = false;
      });
    });
  }

  // Toggles the view between the employee list and the add form
  void _toggleAddEmployeeForm() {
    setState(() {
      _isAddingEmployee = !_isAddingEmployee;
      if (!_isAddingEmployee) {
        // Clear form fields when form is hidden
        _lastNameController.clear();
        _firstNameController.clear();
        _departmentController.clear();
        _jobTitleController.clear();
        _employeeEmailController.clear();
        _registrationNumberController.clear();
        _salaryController.clear();
        _selectedStatus = null;
      }
    });
  }

  // Saves a new employee to Firestore
  Future<void> _saveNewEmployee() async {
    debugPrint('Starting employee save process');
    debugPrint('Organization data: ${widget.organizationData}');
    
    final user = _auth.currentUser;
    debugPrint('Current user: ${user?.uid}');
    
    if (user == null) {
      debugPrint('No authenticated user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Та нэвтэрч орох шаардлагатай!'), // You need to log in!
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // The organization ID should be the user's UID since organizations are stored with their creator's UID
    String organizationId = user.uid;
    debugPrint('Using organization ID: $organizationId');

    debugPrint('User authenticated, checking required fields');

    // Fixed validation logic - check for both first name and last name
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _employeeEmailController.text.isEmpty ||
        _selectedStatus == null) {
      debugPrint('Required fields missing');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ажилтан нэмэхийн тулд нэр, овог, имэйл хаяг, төлөвийг бөглөнө үү!'), // Please fill in first name, last name, email, and status to add an employee!
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('All required fields filled, creating employee data');

    try {
      final employeeData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'fullName': '${_lastNameController.text} ${_firstNameController.text}', // Combined full name
        // 'department': _departmentController.text.isEmpty ? 'N/A' : _departmentController.text,
        'jobTitle': _jobTitleController.text.isEmpty ? 'N/A' : _jobTitleController.text,
        'employeeEmail': _employeeEmailController.text,
        'registrationNumber': _registrationNumberController.text.isEmpty ? 'N/A' : _registrationNumberController.text,
        'salary': _salaryController.text.isEmpty ? 0 : double.tryParse(_salaryController.text) ?? 0,
        'status': _selectedStatus,
        'registrationDate': Timestamp.now(),
        'createdBy': user.uid,
        'lastModified': Timestamp.now(),
      };

      debugPrint('Saving employee data to Firestore');

      // Use a batch write to ensure both operations succeed or fail together
      final batch = _firestore.batch();

      // Add the employee to the employees subcollection
      final employeeRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('employees')
          .doc(); // Auto-generate document ID
      
      batch.set(employeeRef, employeeData);

      // Update the organization's totalEmployees count
      final orgRef = _firestore
          .collection('organizations')
          .doc(organizationId);
      
      batch.update(orgRef, {
        'totalEmployees': FieldValue.increment(1),
        'lastModified': Timestamp.now(),
      });

      // Commit the batch
      await batch.commit();

      debugPrint('Employee data saved successfully and totalEmployees updated');

      // Clear the form fields and close the form
      _toggleAddEmployeeForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Амжилттай хадгалагдлаа!'), // Successfully saved!
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error saving new employee: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ажилтаныг хадгалах үед алдаа гарлаа: $e'), // Error saving employee: $e
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Deletes an employee from Firestore and updates totalEmployees count
  Future<void> _deleteEmployee(String employeeId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Та нэвтэрч орох шаардлагатай!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String organizationId = user.uid;

    try {
      // Use a batch write to ensure both operations succeed or fail together
      final batch = _firestore.batch();

      // Delete the employee from the employees subcollection
      final employeeRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('employees')
          .doc(employeeId);
      
      batch.delete(employeeRef);

      // Update the organization's totalEmployees count
      final orgRef = _firestore
          .collection('organizations')
          .doc(organizationId);
      
      batch.update(orgRef, {
        'totalEmployees': FieldValue.increment(-1),
        'lastModified': Timestamp.now(),
      });

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ажилтан амжилттай устгагдлаа!'), // Employee successfully deleted!
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error deleting employee: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ажилтныг устгах үед алдаа гарлаа: $e'), // Error deleting employee: $e
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    _employeeEmailController.dispose();
    _registrationNumberController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: _isAddingEmployee ? _buildAddEmployeeForm() : _buildEmployeeTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the header with the title and add button
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Ажилтан', // Employees
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _toggleAddEmployeeForm,
          icon: Icon(_isAddingEmployee ? Icons.close : Icons.add, color: Colors.white),
          label: Text(
            _isAddingEmployee ? 'Буцах' : 'Ажилтан Нэмэх', // Go Back / Add Employee
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // Builds the main table of employees
  Widget _buildEmployeeTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Text(
          'Ажилтан байхгүй байна.', // No employees in your organization
          style: TextStyle(color: Colors.black54, fontSize: 18),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search/Filter row (placeholder)
              _buildFilterRow(),
              const SizedBox(height: 12),
              // Table Header
              _buildTableHeader(),
              // Table Body
              ..._employees.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> employee = entry.value;
                return _buildTableRow(index + 1, employee);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the search and filter row (placeholder from image)
  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3139),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Placeholder for search input and dropdowns
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Ажилтнаар хайх', // Search by employee
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Placeholder for filter dropdowns
          const SizedBox(width: 16),
          _buildFilterDropdown(title: 'Түвшин'), // Level
          // const SizedBox(width: 8),
          // _buildFilterDropdown(title: 'Алба хэлтэс'), // Department
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          dropdownColor: const Color(0xFF2B3139),
          style: const TextStyle(color: Colors.white),
          value: null,
          onChanged: (String? newValue) {},
          items: const [
            DropdownMenuItem(value: 'value1', child: Text('Сонгох', style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );
  }

  // Builds the table header row
  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    const padding = EdgeInsets.symmetric(vertical: 12.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B3139),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
      child: const Row(
        children: [
          CustomTableCell(text: '#', flex: 1, textStyle: headerStyle),
          CustomTableCell(text: 'АЖИЛТНЫ НЭР', flex: 4, textStyle: headerStyle),
          CustomTableCell(text: 'ТҮВШИН', flex: 2, textStyle: headerStyle),
          // CustomTableCell(text: 'АЛБА ХЭЛТЭС', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'АЛБАН ТУШААЛ', flex: 4, textStyle: headerStyle),
          CustomTableCell(text: 'САРЫН ЦАЛИН', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'ИМЭЙЛ ХАЯГ', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'ТӨЛӨВ', flex: 2, textStyle: headerStyle),
          CustomTableCell(text: 'БҮРТГЭСЭН ОГНОО', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'ҮЙЛДЭЛ', flex: 2, textStyle: headerStyle),
        ],
      ),
    );
  }

  // Builds a single employee data row
  Widget _buildTableRow(int index, Map<String, dynamic> employee) {
    final statusColor = _getStatusColor(employee['status']);
    // final levelTagColor = _getLevelColor(employee['department']);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3139),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Index and Name
          CustomTableCell(
            text: index.toString(),
            flex: 1,
            alignment: Alignment.centerLeft,
          ),
          CustomTableCell(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade900,
                  child: Text(
                    employee['fullName']?.isNotEmpty == true ? employee['fullName'][0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['fullName'] ?? '${employee['lastName'] ?? ''} ${employee['firstName'] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        employee['jobTitle'] ?? 'N/A',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Level (using department as level)
          // CustomTableCell(
          //   flex: 2,
          //   child: _buildTag(employee['department'] ?? 'N/A', levelTagColor),
          // ),
          // Department
          // CustomTableCell(
          //   text: employee['department'] ?? 'N/A',
          //   flex: 3,
          // ),
          // Job Title
          CustomTableCell(
            text: employee['jobTitle'] ?? 'N/A',
            flex: 4,
          ),
          // Salary
          CustomTableCell(
            text: employee['salary'] != null 
                ? '₮${(employee['salary'] as num).toStringAsFixed(0)}' 
                : 'N/A',
            flex: 3,
          ),
          // Email
          CustomTableCell(
            text: employee['employeeEmail'] ?? 'N/A',
            flex: 3,
          ),
          // Status
          CustomTableCell(
            flex: 2,
            child: _buildTag(employee['status'] ?? 'N/A', statusColor),
          ),
          // Registration Date
          CustomTableCell(
            text: employee['registrationDate'] != null
                ? (employee['registrationDate'] as Timestamp).toDate().toString().split(' ')[0]
                : 'N/A',
            flex: 3,
          ),
          // Actions
          CustomTableCell(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    // TODO: Handle edit action
                  },
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () {
                    // Show confirmation dialog before deleting
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Ажилтныг устгах'),
                          content: Text('Та "${employee['fullName'] ?? '${employee['lastName'] ?? ''} ${employee['firstName'] ?? ''}'}" ажилтныг устгахдаа итгэлтэй байна уу?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Цуцлах'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteEmployee(employee['id']);
                              },
                              child: const Text('Устгах', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to determine status tag color
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Идэвхтэй ажилтан':
        return Colors.green.shade800; // Active employee
      case 'Сул зогсолт':
        return Colors.orange.shade800; // Idle
      case 'Ажлаас гарсан':
        return Colors.red.shade800; // Left job
      case 'Түршсэн ажилтан':
        return Colors.purple.shade800; // Probationary
      default:
        return Colors.grey.shade700; // Default or other statuses
    }
  }

  // Builds a tag/chip for status and level
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Builds the form for adding a new employee
  Widget _buildAddEmployeeForm() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header
              _buildAddEmployeeTableHeader(),
              // Form Fields
              _buildAddEmployeeTableRow(),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement adding another row for another employee
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Одоогоор олон мөр нэмэх боломжгүй!'), // Cannot add multiple rows at the moment!
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Мөр Нэмэх', style: TextStyle(color: Colors.white)), // Add Row
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveNewEmployee,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Баталгаажуулах', style: TextStyle(color: Colors.white)), // Confirm
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the header for the add employee form
  Widget _buildAddEmployeeTableHeader() {
    const headerStyle = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12);
    const padding = EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
      child: const Row(
        children: [
          CustomTableCell(text: '#', flex: 1, textStyle: headerStyle),
          CustomTableCell(text: 'ИМЭЙЛ ХАЯГ', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'ОВОГ', flex: 2, textStyle: headerStyle), // Last name
          CustomTableCell(text: 'НЭР', flex: 2, textStyle: headerStyle), // First name
          CustomTableCell(text: 'РЕГИСТР ДУГААР', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'АЛБАН ТУШААЛ', flex: 4, textStyle: headerStyle),
          CustomTableCell(text: 'САРЫН ЦАЛИН', flex: 3, textStyle: headerStyle),
          CustomTableCell(text: 'ТӨЛӨВ', flex: 2, textStyle: headerStyle),
          CustomTableCell(text: 'ҮЙЛДЭЛ', flex: 2, textStyle: headerStyle),
        ],
      ),
    );
  }

  // Builds the form fields for a single employee to be added
  Widget _buildAddEmployeeTableRow() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CustomTableCell(text: '1', flex: 1),
          // Email Input
          CustomTableCell(
            flex: 3,
            child: _buildInput(null, _employeeEmailController, 'Имэйл хаяг'), // Email address
          ),
          // Last Name Input
          CustomTableCell(
            flex: 2,
            child: _buildInput(null, _lastNameController, 'Овог'),
          ),
          // First Name Input
          CustomTableCell(
            flex: 2,
            child: _buildInput(null, _firstNameController, 'Нэр'),
          ),
          // Registration Number
          CustomTableCell(
            flex: 3,
            child: _buildInput(null, _registrationNumberController, 'Регистр дугаар'),
          ),
          // Job Title Input
          CustomTableCell(
            flex: 4,
            child: _buildInput(null, _jobTitleController, 'Албан тушаал'),
          ),
          // Salary Input
          CustomTableCell(
            flex: 3,
            child: _buildInput('₮', _salaryController, 'Сарын цалин'),
          ),
          // Status Dropdown
          CustomTableCell(
            flex: 2,
            child: _buildStatusDropdown(),
          ),
          // Actions
          CustomTableCell(
            flex: 2,
            child: IconButton(
              onPressed: () {
                // TODO: Implement delete row action for new employee
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Мөр устгах функц одоогоор идэвхгүй байна.'), // Delete row function is currently inactive.
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String? prefixText, TextEditingController? controller, String hintText) {
    // Determine if this is a salary field to set appropriate keyboard type
    final bool isSalaryField = controller == _salaryController;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (prefixText != null)
            Text(prefixText, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          if (prefixText != null) const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isSalaryField ? TextInputType.number : TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text('Төлөв', style: TextStyle(color: Colors.white54, fontSize: 14)),
          value: _selectedStatus,
          dropdownColor: const Color(0xFF2B3139),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          onChanged: (String? newValue) {
            setState(() {
              _selectedStatus = newValue;
            });
          },
          items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
