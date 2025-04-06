import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:Tradezy/pages/bottomnav.dart';

class FinanceApp extends StatefulWidget {
  @override
  _FinanceAppState createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [HomeScreen(), AddTransactionScreen(), StatsScreen(), SavingsScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF007BFF),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF007BFF),
          secondary: const Color(0xFF4DA3FF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2D3436)),
        ),
      ),
      home: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF007BFF),
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: 'Summary',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'Add',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.trending_up_outlined),
                activeIcon: Icon(Icons.trending_up),
                label: 'Invest',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Food and Drink',
    'Income',
    'Shopping',
    'Transportation',
    'Entertainment',
    'Investment',
    'Housing',
    'Tuition Fee',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view transactions.');
      }

      final response = await supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _transactions = response as List<Map<String, dynamic>>;
        _filterTransactions();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch transactions: $error';
        _isLoading = false;
      });
    }
  }

  void _filterTransactions() {
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredTransactions = _transactions;
      } else {
        _filteredTransactions = _transactions
            .where((transaction) => transaction['purpose'] == _selectedCategory)
            .toList();
      }
    });
  }

  Map<String, double> _calculateTotals() {
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var transaction in _filteredTransactions) {
      if (transaction['type'] == 'Income') {
        totalIncome += transaction['amount'] as double;
      } else if (transaction['type'] == 'Expense') {
        totalExpense += transaction['amount'] as double;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'net': totalIncome - totalExpense,
    };
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString.substring(0, 10));
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Financial Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTransactions,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
        color: const Color(0xFF007BFF),
        onRefresh: _fetchTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(totals),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _filterTransactions();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Filter by Category',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 16,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: const Color(0xFF007BFF),
                    ),
                    dropdownColor: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.history,
                        size: 16,
                        color: const Color(0xFF007BFF),
                      ),
                      label: const Text(
                        'View All',
                        style: TextStyle(
                          color: const Color(0xFF007BFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _filteredTransactions.isEmpty
                  ? _buildEmptyTransactionsState()
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _filteredTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = _filteredTransactions[index];
                  return _buildTransactionCard(transaction);
                },
              ),
              const SizedBox(height: 100), // Extra space at bottom for better scrolling
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTransactionScreen()),
          );
        },
        backgroundColor: const Color(0xFF007BFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder image - 120x120 pixels
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF007BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/finance_loading.png', // This is a placeholder - you'll replace this
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading finance loading image: $error');
                  return const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your financial data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder image - 120x120 pixels
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/finance_error.png', // This is a placeholder - you'll replace this
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading finance error image: $error');
                  return const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchTransactions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image - 150x150 pixels
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'images/empty_transactions.png', // This is a placeholder - you'll replace this
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading empty transactions image: $error');
                    return const Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: Color(0xFF007BFF),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedCategory == 'All'
                  ? 'No transactions yet'
                  : 'No transactions in $_selectedCategory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == 'All'
                  ? 'Add your first transaction to get started'
                  : 'Try selecting a different category',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddTransactionScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, double> totals) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007BFF), Color(0xFF4DA3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Placeholder image - 60x60 pixels
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    'images/wallet_icon.png', // This is a placeholder - you'll replace this
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading wallet icon: $error');
                      return const Icon(
                        Icons.account_balance_wallet,
                        size: 30,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${totals['net']!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Income',
                  'RM ${totals['income']!.toStringAsFixed(2)}',
                  Icons.arrow_upward,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBalanceCard(
                  'Expenses',
                  'RM ${totals['expense']!.toStringAsFixed(2)}',
                  Icons.arrow_downward,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final bool isIncome = transaction['type'] == 'Income';
    final Color typeColor = isIncome ? Colors.green : Colors.red;
    final IconData typeIcon = isIncome ? Icons.arrow_upward : Icons.arrow_downward;

    // Get icon based on purpose
    IconData purposeIcon;
    switch (transaction['purpose']) {
      case 'Food and Drink':
        purposeIcon = Icons.restaurant;
        break;
      case 'Shopping':
        purposeIcon = Icons.shopping_bag;
        break;
      case 'Income':
        purposeIcon = Icons.attach_money;
        break;
      case 'Transportation':
        purposeIcon = Icons.directions_car;
        break;
      case 'Entertainment':
        purposeIcon = Icons.movie;
        break;
      case 'Investment':
        purposeIcon = Icons.trending_up;
        break;
      case 'Housing':
        purposeIcon = Icons.home;
        break;
      case 'Tuition Fee':
        purposeIcon = Icons.school;
        break;
      default:
        purposeIcon = Icons.category;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                purposeIcon,
                color: typeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['purpose'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction['created_at'].toString()),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${transaction['amount'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        typeIcon,
                        size: 12,
                        color: typeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        transaction['type'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddTransactionScreen extends StatefulWidget {
  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _transactionType = 'Expense';
  String _selectedPurpose = 'Food and Drink';
  bool _isLoading = false;

  final List<String> _purposes = [
    'Food and Drink',
    'Shopping',
    'Income',
    'Transportation',
    'Entertainment',
    'Investment',
    'Housing',
    'Tuition Fee'
  ];

  final supabase = Supabase.instance.client;

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to add a transaction.');
      }

      await supabase.from('transactions').insert({
        'user_id': user.id,
        'type': _transactionType,
        'amount': double.parse(_amountController.text.trim()),
        'purpose': _selectedPurpose,
      });

      setState(() {
        _isLoading = false;
        _amountController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction successfully added!'),
            backgroundColor: Color(0xFF007BFF),
          ),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add transaction: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNav()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placeholder image - 200x150 pixels
              Center(
                child: Container(
                  width: 200,
                  height: 150,
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/add_transaction.png', // This is a placeholder - you'll replace this
                      width: 160,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading add transaction image: $error');
                        return const Icon(
                          Icons.add_card,
                          size: 80,
                          color: Color(0xFF007BFF),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _transactionType = 'Income';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _transactionType == 'Income'
                                      ? const Color(0xFF007BFF)
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Income',
                                    style: TextStyle(
                                      color: _transactionType == 'Income'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _transactionType = 'Expense';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _transactionType == 'Expense'
                                      ? const Color(0xFF007BFF)
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: _transactionType == 'Expense'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Amount (RM)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'RM ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF007BFF),
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2D3436),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Please enter a valid positive amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Purpose',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonFormField(
                        value: _selectedPurpose,
                        items: _purposes.map((String purpose) {
                          return DropdownMenuItem(value: purpose, child: Text(purpose));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPurpose = value as String;
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 16,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: const Color(0xFF007BFF),
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Save Transaction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final supabase = Supabase.instance.client;
  Map<String, double> _transactionsByPurpose = {};
  Map<String, double> _incomeByMonth = {};
  Map<String, double> _expenseByMonth = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view statistics.');
      }

      final purposeResponse = await supabase
          .rpc('get_transactions_by_purpose', params: {'user_id_param': user.id});

      final incomeResponse = await supabase
          .rpc('get_income_by_month', params: {'user_id_param': user.id});

      final expenseResponse = await supabase
          .rpc('get_expense_by_month', params: {'user_id_param': user.id});

      setState(() {
        _transactionsByPurpose = {
          for (var item in purposeResponse as List<dynamic>)
            item['purpose']: (item['total_amount'] as num?)?.toDouble() ?? 0.0
        };
        _incomeByMonth = {
          for (var item in incomeResponse as List<dynamic>)
            item['month']: (item['total_income'] as num?)?.toDouble() ?? 0.0
        };
        _expenseByMonth = {
          for (var item in expenseResponse as List<dynamic>)
            item['month']: (item['total_expense'] as num?)?.toDouble() ?? 0.0
        };
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch stats: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = {..._incomeByMonth.keys, ..._expenseByMonth.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNav()),
            );
          },
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image - 120x120 pixels
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'images/stats_loading.png', // This is a placeholder - you'll replace this
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading stats loading image: $error');
                    return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your statistics...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image - 120x120 pixels
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'images/stats_error.png', // This is a placeholder - you'll replace this
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading stats error image: $error');
                    return const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF007BFF),
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placeholder image - 200x120 pixels
              Center(
                child: Container(
                  width: 200,
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/stats_header.png', // This is a placeholder - you'll replace this
                      width: 160,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading stats header image: $error');
                        return const Icon(
                          Icons.bar_chart,
                          size: 80,
                          color: Color(0xFF007BFF),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const Text(
                'Transactions by Purpose',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _transactionsByPurpose.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
                    : PieChart(
                  PieChartData(
                    sections: _transactionsByPurpose.entries.map((entry) {
                      final index = _transactionsByPurpose.keys.toList().indexOf(entry.key);
                      return PieChartSectionData(
                        value: entry.value,
                        title: '${entry.key}\nRM${entry.value.toStringAsFixed(0)}',
                        color: Colors.primaries[index % Colors.primaries.length],
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Income and Expenses by Month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: allMonths.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No income or expenses yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
                    : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (allMonths.isNotEmpty)
                        ? (_incomeByMonth.values.isNotEmpty || _expenseByMonth.values.isNotEmpty)
                        ? (_incomeByMonth.values.isNotEmpty
                        ? _incomeByMonth.values.reduce((a, b) => a > b ? a : b)
                        : _expenseByMonth.values.reduce((a, b) => a > b ? a : b)) *
                        1.2
                        : 100
                        : 100,
                    barGroups: allMonths.map((month) {
                      final index = allMonths.indexOf(month);
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: _incomeByMonth[month] ?? 0,
                            color: Colors.green,
                            width: 12,
                          ),
                          BarChartRodData(
                            toY: _expenseByMonth[month] ?? 0,
                            color: Colors.red,
                            width: 12,
                          ),
                        ],
                        barsSpace: 4,
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < allMonths.length) {
                              return Text(
                                allMonths[index],
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 40,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.green, size: 12),
                      SizedBox(width: 4),
                      Text('Income'),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text('Expenses'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavingsScreen extends StatefulWidget {
  @override
  _SavingsScreenState createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final supabase = Supabase.instance.client;
  double? _totalIncome;
  double? _needs;
  double? _wants;
  double? _savings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTotalIncome();
  }

  Future<void> _fetchTotalIncome() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view savings suggestions.');
      }

      final incomeResponse = await supabase
          .from('incomes')
          .select('amount')
          .eq('user_id', user.id);
      final incomes = (incomeResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

      final transactionResponse = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id)
          .eq('type', 'Income');
      final transactionIncomes = (transactionResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

      final totalIncome = (incomes + transactionIncomes)
          .fold<double>(0, (sum, amount) => sum + amount);

      setState(() {
        _totalIncome = totalIncome;
        _needs = totalIncome * 0.5;
        _wants = totalIncome * 0.3;
        _savings = totalIncome * 0.2;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch income: $error';
        _isLoading = false;
      });
    }
  }

  Map<String, double> _calculateAllocations(double savings) {
    return {
      'MIGA (30%)': savings * 0.3,
      'ASNB (20%)': savings * 0.2,
      'Wahed (20%)': savings * 0.2,
      'Keep for Trading (30%)': savings * 0.3,
    };
  }

  final Map<String, Map<String, String>> _platforms = {
    'MIGA': {
      'image': 'images/maybank.png',
      'link': 'https://play.google.com/store/apps/details?id=com.maybank2u.life&hl=en&pli=1',
      'displayLink': 'Maybank App Link',
    },
    'ASNB': {
      'image': 'images/asnb.jpg',
      'link': 'https://play.google.com/store/apps/details?id=com.pnb.myASNBmobile&hl=en',
      'displayLink': 'ASNB App Link',
    },
    'Wahed': {
      'image': 'images/wahed.jpg',
      'link': 'https://play.google.com/store/apps/details?id=com.wahed.mobile&hl=en',
      'displayLink': 'Wahed App Link',
    },
  };

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Savings Suggestions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BottomNav()),
            );
          },
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image - 120x120 pixels
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'images/savings_loading.png', // This is a placeholder - you'll replace this
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading savings loading image: $error');
                    return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your savings data...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image - 120x120 pixels
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'images/savings_error.png', // This is a placeholder - you'll replace this
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading savings error image: $error');
                    return const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchTotalIncome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Placeholder image - 180x120 pixels
        Center(
        child: Container(
        width: 180,
          height: 120,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF007BFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Image.asset(
              'images/savings_header.png', // This is a placeholder - you'll replace this
              width: 140,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading savings header image: $error');
                return const Icon(
                  Icons.savings,
                  size: 70,
                  color: Color(0xFF007BFF),
                );
              },
            ),
          ),
        ),
      ),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Total Income',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RM${_totalIncome!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Budget Allocation (50/30/20 Rule)',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3436),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildAllocationItem(
                'Needs (50%)',
                _needs!,
                Colors.orange,
                Icons.home,
              ),
              const Divider(),
              _buildAllocationItem(
                'Wants (30%)',
                _wants!,
                Colors.purple,
                Icons.shopping_bag,
              ),
              const Divider(),
              _buildAllocationItem(
                'Savings (20%)',
                _savings!,
                const Color(0xFF007BFF),
                Icons.savings,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Savings Allocation Suggestions',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3436),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Heres how you could allocate your savings:',
      style: TextStyle(
        fontSize: 14,
        color: Color(0xFF7F8C8D),
      ),
    ),
    const SizedBox(height: 16),
    ..._calculateAllocations(_savings!).entries.map((entry) {
    final platformKey = entry.key.split(' ')[0];
    if (platformKey == 'Keep') {
    return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
    children: [
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.grey[200],
    borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
    Icons.account_balance_wallet,
    size: 30,
    color: Colors.grey,
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    entry.key,
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Color(0xFF2D3436),
    ),
    ),
    Text(
    'RM${entry.value.toStringAsFixed(2)}',
    style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF7F8C8D),
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    );
    } else {
    final platform = _platforms[platformKey]!;
    return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
    children: [
    // Placeholder image - 50x50 pixels
    Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
    color: const Color(0xFF007BFF).withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
    child: Image.asset(
    platform['image']!,
    width: 40,
    height: 40,
    errorBuilder: (context, error, stackTrace) {
    print('Error loading platform image: $error');
    return Icon(
    Icons.account_balance,
    size: 30,
    color: const Color(0xFF007BFF),
    );
    },
    ),
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    entry.key,
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Color(0xFF2D3436),
    ),
    ),
    Text(
    'RM${entry.value.toStringAsFixed(2)}',
    style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF7F8C8D),
    ),
    ),
    GestureDetector(
    onTap: () => _launchURL(platform['link']!),
    child: Text(
    platform['displayLink']!,
    style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF007BFF),
    decoration: TextDecoration.underline,
    ),
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    );
    }
    }).toList(),
    const SizedBox(height: 16),
    Card(
    elevation: 0,
    color: const Color(0xFF007BFF).withOpacity(0.1),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
    children: [
    const Icon(
    Icons.info_outline,
    color: Color(0xFF007BFF),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Text(
    'The remaining 30% of your savings can be kept as cash or allocated based on your goals in trading.',
    style: TextStyle(
    fontSize: 14,
    color: const Color(0xFF007BFF).withOpacity(0.8),
    ),
    ),
    ),
    ],
    ),
    ),
    ),
    ],
    ),
    ),
    );
  }

  Widget _buildAllocationItem(String title, double amount, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF2D3436),
              ),
            ),
          ),
          Text(
            'RM${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

