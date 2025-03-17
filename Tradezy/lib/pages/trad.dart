import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Tradezy/pages/portfolio.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:ui'; // For BackdropFilter

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  _LearnPageState createState() => _LearnPageState();
}


class _LearnPageState extends State<LearnPage> {
  int _selectedIndex = 0;
  double virtualMoney = 10000.0;
  Map<String, List<FlSpot>> priceData = {
    'Bitcoin': [],
    'Gold': [],
    'Tesla': [],
    'Apple': [],
    'Maybank': [],
  };
  Map<String, Map<String, double>> investments = {
    'Bitcoin': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Gold': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Tesla': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Apple': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Maybank': {'quantity': 0.0, 'purchasePrice': 0.0},
  };
  String selectedAsset = 'Bitcoin';
  String selectedTimePeriod = '1D';
  bool _isLoading = true;
  String? _errorMessage;
  double usdToMyrRate = 4.3;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    fetchExchangeRate().then((_) => fetchPriceData());
    _loadInitialVirtualMoney();
  }

  Future<void> _loadInitialVirtualMoney() async {
    if (supabase.auth.currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('virtual_money')
          .eq('id', supabase.auth.currentUser!.id)
          .single();
      final dbVirtualMoney = (response['virtual_money'] as num?)?.toDouble() ?? 10000.0;
      setState(() {
        virtualMoney = dbVirtualMoney;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load virtual money: $e';
      });
    }
  }

  Future<void> fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          usdToMyrRate = data['rates']['MYR'].toDouble();
        });
      } else {
        throw Exception('Failed to fetch exchange rate');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching exchange rate: $e';
        usdToMyrRate = 4.3;
      });
    }
  }

  Future<void> fetchPriceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bitcoinData = await fetchBitcoinPriceData(selectedTimePeriod);
      setState(() {
        priceData['Bitcoin'] = bitcoinData;
      });

      setState(() {
        priceData['Gold'] = [
          FlSpot(0, 2600 * usdToMyrRate),
          FlSpot(1, 2620 * usdToMyrRate),
          FlSpot(2, 2590 * usdToMyrRate),
          FlSpot(3, 2630 * usdToMyrRate),
          FlSpot(4, 2610 * usdToMyrRate),
        ];
        priceData['Tesla'] = [
          FlSpot(0, 350 * usdToMyrRate),
          FlSpot(1, 355 * usdToMyrRate),
          FlSpot(2, 340 * usdToMyrRate),
          FlSpot(3, 360 * usdToMyrRate),
          FlSpot(4, 365 * usdToMyrRate),
        ];
        priceData['Apple'] = [
          FlSpot(0, 250 * usdToMyrRate),
          FlSpot(1, 253 * usdToMyrRate),
          FlSpot(2, 247 * usdToMyrRate),
          FlSpot(3, 255 * usdToMyrRate),
          FlSpot(4, 257 * usdToMyrRate),
        ];
        priceData['Maybank'] = [
          FlSpot(0, 10.50),
          FlSpot(1, 10.60),
          FlSpot(2, 10.40),
          FlSpot(3, 10.70),
          FlSpot(4, 10.55),
        ];
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        priceData['Bitcoin'] = [
          FlSpot(0, 84500 * usdToMyrRate),
          FlSpot(1, 84600 * usdToMyrRate),
          FlSpot(2, 84300 * usdToMyrRate),
          FlSpot(3, 84800 * usdToMyrRate),
          FlSpot(4, 84500 * usdToMyrRate),
        ];
        _errorMessage = 'Failed to fetch price data: $e. Using fallback data.';
        _isLoading = false;
      });
    }
  }

  Future<List<FlSpot>> fetchBitcoinPriceData(String timePeriod) async {
    String url;
    int intervalMinutes;
    switch (timePeriod) {
      case '1D':
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1';
        intervalMinutes = 60;
        break;
      case '1W':
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=7';
        intervalMinutes = 240;
        break;
      case '1M':
      default:
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=30';
        intervalMinutes = 1440;
        break;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prices = data['prices'] as List;
      final filteredPrices = prices.asMap().entries.where((entry) => entry.key % (intervalMinutes ~/ 60) == 0).toList();
      return filteredPrices.map((entry) {
        final priceInUsd = (entry.value[1] as num).toDouble();
        final priceInMyr = priceInUsd * usdToMyrRate;
        return FlSpot(entry.key.toDouble(), priceInMyr);
      }).toList();
    } else {
      throw Exception('Failed to fetch Bitcoin price data');
    }
  }

  Future<void> _updateVirtualMoney(double newMoney) async {
    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    try {
      await supabase
          .from('profiles')
          .update({'virtual_money': newMoney})
          .eq('id', supabase.auth.currentUser!.id);
      setState(() {
        virtualMoney = newMoney;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Virtual money updated to RM ${newMoney.toStringAsFixed(2)}')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update virtual money: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update virtual money: $e')),
      );
    }
  }

  void _onMoneyUpdate(double newMoney) {
    setState(() {
      virtualMoney = newMoney;
    });
  }

  void _onInvestmentsUpdate(Map<String, Map<String, double>> newInvestments) {
    setState(() {
      investments = newInvestments;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        fetchPriceData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HowTradingWorksPage(),
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Virtual Money: RM ${virtualMoney.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        virtualMoney += 5000.0;
                      });
                      _updateVirtualMoney(virtualMoney);
                    },
                    child: const Text('Add RM 5,000'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        virtualMoney = 10000.0;
                      });
                      _updateVirtualMoney(10000.0);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Price Trends',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<String>(
                    value: selectedAsset,
                    dropdownColor: Colors.grey[900],
                    items: ['Bitcoin', 'Gold', 'Tesla', 'Apple', 'Maybank'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedAsset = newValue!;
                      });
                    },
                  ),
                  DropdownButton<String>(
                    value: selectedTimePeriod,
                    dropdownColor: Colors.grey[900],
                    items: ['1D', '1W', '1M'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedTimePeriod = newValue!;
                        fetchPriceData();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: fetchPriceData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : priceData[selectedAsset]!.isEmpty
                          ? const Center(
                              child: Text(
                                'No data available for this asset.',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            )
                          : Container(
                              height: 400,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _getFixedYInterval(selectedAsset), 
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.white24,
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 60,
                                        interval: _getFixedYInterval(selectedAsset), 
                                        getTitlesWidget: (value, meta) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Text(
                                              _formatPrice(value, selectedAsset),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: false,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: false,
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: false,
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(color: Colors.white24, width: 1),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: priceData[selectedAsset]!,
                                      isCurved: true,
                                      color: Colors.blueAccent,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                  minY: _getMinY(selectedAsset) != null ? _getMinY(selectedAsset)! * 0.7 : null, 
                                  maxY: _getMaxY(selectedAsset) != null ? _getMaxY(selectedAsset)! * 1.3 : null, 
                                ),
                              ),
                            ),
            ],
          ),
        ),
      ),
      PortfolioPage(
        virtualMoney: virtualMoney,
        priceData: priceData,
        investments: investments,
        selectedTimePeriod: selectedTimePeriod,
        onMoneyUpdate: _onMoneyUpdate,
        onInvestmentsUpdate: _onInvestmentsUpdate,
        onFetchPriceData: fetchPriceData,
      ),
      const BestTradingPlatformsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Learn', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'How Trading Works',
            backgroundColor: Colors.black,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Trends',
            backgroundColor: Colors.black,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Portfolio',
            backgroundColor: Colors.black,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center),
            label: 'Platforms',
            backgroundColor: Colors.black,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }

  double _getFixedYInterval(String asset) {
    switch (asset) {
      case 'Bitcoin':
        return 50000.0; 
      case 'Gold':
        return 10000.0; 
      case 'Tesla':
        return 5000.0; 
      case 'Apple':
        return 5000.0; 
      case 'Maybank':
        return 2.0; 
      default:
        return 10000.0; 
    }
  }

  double? _getMinY(String asset) {
    final data = priceData[asset];
    if (data == null || data.isEmpty) return null;
    return data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
  }

  double? _getMaxY(String asset) {
    final data = priceData[asset];
    if (data == null || data.isEmpty) return null;
    return data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
  }

  String _formatPrice(double value, String asset) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k'; 
    } else if (asset == 'Maybank') {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(0); 
    }
  }
}


class HowTradingWorksPage extends StatelessWidget {
  const HowTradingWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.white, width: 1.0),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Understanding Trading Basics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Master the art of trading financial assets like stocks, cryptocurrencies, and commodities to profit from price movements.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: const BorderSide(color: Colors.white, width: 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.show_chart, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Key Trading Concepts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEnhancedBulletPoint(
                    icon: Icons.trending_up,
                    text: 'Buy and Sell: Buy low, sell high to make a profit. Alternatively, use short-selling to profit from falling prices.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.swap_horiz,
                    text: 'Long and Short Positions: Go long if you expect prices to rise, or short if you anticipate a decline.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.attach_money,
                    text: 'Leverage: Borrow funds to amplify your position, boosting both potential gains and losses.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.shield,
                    text: 'Risk Management: Use stop-loss orders and invest only what you can afford to lose.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.bar_chart,
                    text: 'Technical Analysis: Analyze price charts and indicators (e.g., Moving Averages, RSI) for predictions.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.trending_up_outlined,
                    text: 'Fundamental Analysis: Assess an asset’s value using economic data, earnings, and market trends.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: const BorderSide(color: Colors.white, width: 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Getting Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Follow these steps to begin your trading journey:',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _buildStep('1. Choose a platform (explore Best Trading Platforms).'),
                  _buildStep('2. Practice with a demo account to build confidence.'),
                  _buildStep('3. Create a trading plan with clear goals and risk limits.'),
                  _buildStep('4. Start with small investments and scale up with experience.'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Quiz Section
          const TradingQuizSection(),
        ],
      ),
    );
  }

  Widget _buildEnhancedBulletPoint({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class TradingQuizSection extends StatefulWidget {
  const TradingQuizSection({super.key});

  @override
  State<TradingQuizSection> createState() => _TradingQuizSectionState();
}

class _TradingQuizSectionState extends State<TradingQuizSection> {
  final List<Map<String, dynamic>> quizQuestions = [
    {
      'question': 'What does it mean to "go long" in trading?',
      'options': [
        'A) Selling an asset to profit from a price drop',
        'B) Buying an asset expecting its price to rise',
        'C) Holding an asset for a short period',
        'D) Using leverage to amplify losses'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What is the purpose of a stop-loss order?',
      'options': [
        'A) To automatically buy an asset at a lower price',
        'B) To limit potential losses by selling an asset at a predetermined price',
        'C) To increase leverage on a position',
        'D) To analyze price charts'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What does leverage allow traders to do?',
      'options': [
        'A) Trade without any risk',
        'B) Borrow funds to increase the size of their position',
        'C) Avoid paying taxes on profits',
        'D) Automatically close losing trades'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What is technical analysis primarily based on?',
      'options': [
        'A) Economic data and company earnings',
        'B) Price charts and trading indicators',
        'C) News headlines and rumors',
        'D) Government policies'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What should you do first before starting to trade with real money?',
      'options': [
        'A) Practice with a demo account',
        'B) Invest all your savings',
        'C) Use maximum leverage',
        'D) Ignore risk management'
      ],
      'correctAnswer': 0,
    },
  ];

  List<int?> userAnswers = List.filled(5, null); // Track user's selected answers
  bool isSubmitted = false;
  int score = 0;

  void _submitQuiz() {
    setState(() {
      isSubmitted = true;
      score = 0;
      for (int i = 0; i < quizQuestions.length; i++) {
        if (userAnswers[i] == quizQuestions[i]['correctAnswer']) {
          score++;
        }
      }
    });
  }

  void _resetQuiz() {
    setState(() {
      userAnswers = List.filled(5, null);
      isSubmitted = false;
      score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.white, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.quiz, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Test Your Knowledge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Answer the following questions to test your understanding of trading basics:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ...List.generate(quizQuestions.length, (index) {
                  return _buildQuizQuestion(index);
                }),
                const SizedBox(height: 20),
                if (isSubmitted)
                  Column(
                    children: [
                      Text(
                        'Your Score: $score/${quizQuestions.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _resetQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: _submitQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Check Answers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizQuestion(int index) {
    final question = quizQuestions[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${index + 1}: ${question['question']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(question['options'].length, (optionIndex) {
            return RadioListTile<int>(
              value: optionIndex,
              groupValue: userAnswers[index],
              onChanged: isSubmitted
                  ? null
                  : (value) {
                      setState(() {
                        userAnswers[index] = value;
                      });
                    },
              title: Text(
                question['options'][optionIndex],
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              activeColor: Colors.blueAccent,
              tileColor: isSubmitted
                  ? (optionIndex == question['correctAnswer']
                      ? Colors.green.withOpacity(0.2)
                      : userAnswers[index] == optionIndex
                          ? Colors.red.withOpacity(0.2)
                          : null)
                  : null,
            );
          }),
          if (isSubmitted)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                userAnswers[index] == question['correctAnswer']
                    ? 'Correct! ✅'
                    : 'Incorrect. The correct answer is: ${question['options'][question['correctAnswer']]} ❌',
                style: TextStyle(
                  color: userAnswers[index] == question['correctAnswer'] ? Colors.green : Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class BestTradingPlatformsPage extends StatefulWidget {
  const BestTradingPlatformsPage({super.key});

  @override
  _BestTradingPlatformsPageState createState() => _BestTradingPlatformsPageState();
}

class _BestTradingPlatformsPageState extends State<BestTradingPlatformsPage> {
  String selectedCategory = 'Beginner';
  bool _isLaunchingUrl = false;

  final Map<String, List<Map<String, String>>> platforms = {
    'Beginner': [
      {
        'title': 'Moomoo',
        'pros': 'Commission-free stocks, powerful analytical tools, paper trading feature.',
        'cons': 'Limited crypto support, learning curve for beginners.',
        'image': 'images/moomoo.png',
        'link': 'https://play.google.com/store/apps/details?id=com.moomoo.trade&hl=en'
      },
      {
        'title': 'Luno',
        'pros': 'User-friendly, good for cryptocurrency trading, regulated.',
        'cons': 'Limited trading pairs, higher fees.',
        'image': 'images/luno.jpeg',
        'link': 'https://play.google.com/store/apps/details?id=co.bitx.android.wallet&hl=en'
      },
    ],
    'Amateur': [
      {
        'title': 'XM',
        'pros': 'Regulated broker, multiple trading instruments, good customer support.',
        'cons': 'Moderate risk, higher fees on some accounts.',
        'image': 'images/xm.png',
        'link': 'https://play.google.com/store/apps/details?id=com.xm.webapp&hl=en'
      },
      {
        'title': 'FBS',
        'pros': 'High leverage, fast execution, cashback program.',
        'cons': 'High risk, withdrawal limitations.',
        'image': 'images/fbs.png',
        'link': 'https://play.google.com/store/apps/details?id=com.fbs.pa&hl=en'
      },
    ],
    'Pro': [
      {
        'title': 'ExpertOption',
        'pros': 'Easy to use, good for short-term trading, social trading features.',
        'cons': 'High risk, limited assets, not available in some regions.',
        'image': 'images/eo.jpeg',
        'link': 'https://play.google.com/store/apps/details?id=com.expertoption&hl=en'
      },
      {
        'title': 'Octa Trading',
        'pros': 'Low spreads, multiple account types, high leverage.',
        'cons': 'High risk, strict regulations in some countries.',
        'image': 'images/octa.png',
        'link': 'https://play.google.com/store/apps/details?id=com.octafx&hl=en'
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Trading Platforms'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Trading Platforms for 2025',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find the best platform for your trading level.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select your experience level:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildDropdown(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: platforms[selectedCategory]?.length ?? 0,
              itemBuilder: (context, index) {
                final platform = platforms[selectedCategory]![index];
                return _buildPlatformCard(
                  title: platform['title']!,
                  pros: platform['pros']!,
                  cons: platform['cons']!,
                  image: platform['image']!,
                  link: platform['link']!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white, width: 1.0),
      ),
      child: DropdownButton<String>(
        value: selectedCategory,
        dropdownColor: Colors.black,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        underline: const SizedBox(),
        isExpanded: true,
        onChanged: (String? newValue) {
          setState(() {
            selectedCategory = newValue!;
          });
        },
        items: ['Beginner', 'Amateur', 'Pro'].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlatformCard({
    required String title,
    required String pros,
    required String cons,
    required String image,
    required String link,
  }) {
    return Card(
      color: Colors.black,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.white, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    image,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    semanticLabel: 'Platform logo for $title',
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error, color: Colors.white, size: 50);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Pros:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pros,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cons:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cons,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: const BorderSide(color: Colors.white, width: 1.0),
                ),
              ),
              onPressed: _isLaunchingUrl
                  ? null
                  : () async {
                      setState(() {
                        _isLaunchingUrl = true;
                      });
                      await launchURL(link);
                      setState(() {
                        _isLaunchingUrl = false;
                      });
                    },
              child: _isLaunchingUrl
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Install',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching URL: $e')),
      );
    }
  }
}