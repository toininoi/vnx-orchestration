#!/usr/bin/env python3
"""
Test Suite for Tag Intelligence Engine
Tests tag normalization, combination tracking, prevention rule generation.
"""

import unittest
import tempfile
import sqlite3
import json
from pathlib import Path
import sys

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts'))

from tag_intelligence import TagIntelligenceEngine


class TestTagNormalization(unittest.TestCase):
    """Test tag normalization to standardized taxonomy"""

    def setUp(self):
        """Create temporary database for testing"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_phase_normalization(self):
        """Test phase tag normalization"""
        # Design phase
        result = self.engine.normalize_tags(['design', 'planning', 'architecture'])
        self.assertIn('design-phase', result)

        # Implementation phase
        result = self.engine.normalize_tags(['implementation', 'coding', 'development'])
        self.assertIn('implementation-phase', result)

        # Testing phase
        result = self.engine.normalize_tags(['testing', 'validation', 'qa'])
        self.assertIn('testing-phase', result)

        # Production phase
        result = self.engine.normalize_tags(['production', 'deployment', 'release'])
        self.assertIn('production-phase', result)

    def test_component_normalization(self):
        """Test component tag normalization"""
        # Crawler component
        result = self.engine.normalize_tags(['crawler', 'scraping', 'web'])
        self.assertIn('crawler-component', result)

        # Storage component
        result = self.engine.normalize_tags(['storage', 'database', 'persistence'])
        self.assertIn('storage-component', result)

        # API component
        result = self.engine.normalize_tags(['api', 'endpoint', 'controller'])
        self.assertIn('api-component', result)

    def test_issue_normalization(self):
        """Test issue tag normalization"""
        # Validation error
        result = self.engine.normalize_tags(['validation-error', 'invalid-data'])
        self.assertIn('validation-error', result)

        # Performance issue
        result = self.engine.normalize_tags(['performance', 'slow', 'optimization'])
        self.assertIn('performance-issue', result)

        # Memory problem
        result = self.engine.normalize_tags(['memory', 'memory-leak', 'oom'])
        self.assertIn('memory-problem', result)

        # Race condition
        result = self.engine.normalize_tags(['race', 'concurrency', 'threading'])
        self.assertIn('race-condition', result)

    def test_severity_normalization(self):
        """Test severity tag normalization"""
        # Critical blocker
        result = self.engine.normalize_tags(['critical', 'blocker', 'urgent'])
        self.assertIn('critical-blocker', result)

        # High priority
        result = self.engine.normalize_tags(['high', 'important'])
        self.assertIn('high-priority', result)

        # Medium impact
        result = self.engine.normalize_tags(['medium', 'moderate'])
        self.assertIn('medium-impact', result)

    def test_action_normalization(self):
        """Test action tag normalization"""
        # Needs refactor
        result = self.engine.normalize_tags(['refactor', 'technical-debt'])
        self.assertIn('needs-refactor', result)

        # Needs validation
        result = self.engine.normalize_tags(['validation', 'verify'])
        self.assertIn('needs-validation', result)

        # Needs retry logic
        result = self.engine.normalize_tags(['retry', 'resilience'])
        self.assertIn('needs-retry-logic', result)

    def test_duplicate_removal(self):
        """Test that duplicates are removed during normalization"""
        result = self.engine.normalize_tags(['design', 'planning', 'design', 'architecture'])
        # Should only have one design-phase tag
        self.assertEqual(result.count('design-phase'), 1)

    def test_alphabetical_sorting(self):
        """Test that tags are sorted alphabetically"""
        result = self.engine.normalize_tags(['zzz', 'aaa', 'mmm'])
        # Should be sorted
        self.assertEqual(result, tuple(sorted(result)))

    def test_unknown_tag_preservation(self):
        """Test that unknown tags are preserved as lowercase"""
        result = self.engine.normalize_tags(['unknown-tag', 'CUSTOM-TAG'])
        self.assertIn('unknown-tag', result)
        self.assertIn('custom-tag', result)


class TestTagCombinationTracking(unittest.TestCase):
    """Test tag combination analysis and tracking"""

    def setUp(self):
        """Create temporary database for testing"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_single_tag_analysis(self):
        """Test analysis of single tag combination"""
        result = self.engine.analyze_multi_tag_patterns(
            tags=['validation-error'],
            phase='implementation-phase',
            terminal='T1',
            outcome='failure'
        )

        self.assertTrue(result['analyzed'])
        self.assertEqual(result['occurrence_count'], 1)
        self.assertFalse(result['prevention_rule_generated'])

    def test_multi_tag_analysis(self):
        """Test analysis of multiple tag combination"""
        result = self.engine.analyze_multi_tag_patterns(
            tags=['crawler', 'performance', 'critical'],
            phase='production-phase',
            terminal='T2'
        )

        self.assertTrue(result['analyzed'])
        self.assertIn('crawler-component', result['tag_combination'])
        self.assertIn('performance-issue', result['tag_combination'])
        self.assertIn('critical-blocker', result['tag_combination'])

    def test_recurring_combination_detection(self):
        """Test prevention rule generation after 2+ occurrences"""
        tags = ['validation-error', 'api-component']

        # First occurrence
        result1 = self.engine.analyze_multi_tag_patterns(tags, terminal='T1')
        self.assertEqual(result1['occurrence_count'], 1)
        self.assertFalse(result1['prevention_rule_generated'])

        # Second occurrence - should generate prevention rule
        result2 = self.engine.analyze_multi_tag_patterns(tags, terminal='T2')
        self.assertEqual(result2['occurrence_count'], 2)
        self.assertTrue(result2['prevention_rule_generated'])
        self.assertIn('prevention_rule', result2)

    def test_empty_tags_handling(self):
        """Test handling of empty tag list"""
        result = self.engine.analyze_multi_tag_patterns(tags=[])
        self.assertFalse(result['analyzed'])
        self.assertEqual(result['reason'], 'no_tags')

    def test_combination_persistence(self):
        """Test that tag combinations persist in database"""
        tags = ['storage', 'memory-leak']

        # Analyze combination
        self.engine.analyze_multi_tag_patterns(tags, terminal='T1')

        # Query database directly
        db = sqlite3.connect(self.temp_db.name)
        db.row_factory = sqlite3.Row
        cursor = db.execute("SELECT tag_tuple, occurrence_count FROM tag_combinations")
        row = cursor.fetchone()

        self.assertIsNotNone(row)
        stored_tags = json.loads(row['tag_tuple'])
        self.assertIn('storage-component', stored_tags)
        self.assertIn('memory-problem', stored_tags)
        self.assertEqual(row['occurrence_count'], 1)

        db.close()


class TestPreventionRuleGeneration(unittest.TestCase):
    """Test prevention rule generation logic"""

    def setUp(self):
        """Create temporary database for testing"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_critical_prevention_rule_type(self):
        """Test critical prevention rule classification"""
        tags = ['critical-blocker', 'production-phase', 'storage-component']

        # Generate 2 occurrences to trigger rule creation
        self.engine.analyze_multi_tag_patterns(tags)
        result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        self.assertEqual(rule['rule_type'], 'critical-prevention')

    def test_validation_check_rule_type(self):
        """Test validation check rule classification"""
        tags = ['validation-error', 'api-component', 'design-phase']

        # Generate 2 occurrences
        self.engine.analyze_multi_tag_patterns(tags)
        result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        self.assertEqual(rule['rule_type'], 'validation-check')

    def test_performance_optimization_rule_type(self):
        """Test performance optimization rule classification"""
        tags = ['performance-issue', 'crawler-component']

        # Generate 2 occurrences
        self.engine.analyze_multi_tag_patterns(tags)
        result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        self.assertEqual(rule['rule_type'], 'performance-optimization')

    def test_memory_management_rule_type(self):
        """Test memory management rule classification"""
        tags = ['memory-problem', 'api-component']

        # Generate 2 occurrences
        self.engine.analyze_multi_tag_patterns(tags)
        result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        self.assertEqual(rule['rule_type'], 'memory-management')

    def test_confidence_calculation(self):
        """Test confidence score increases with occurrences"""
        tags = ['validation-error', 'storage-component']

        # Generate multiple occurrences
        for i in range(5):
            result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        # Confidence should be 5/10 = 0.5
        self.assertAlmostEqual(rule['confidence'], 0.5, places=1)

    def test_max_confidence_cap(self):
        """Test confidence capped at 1.0"""
        tags = ['critical-blocker', 'memory-problem']

        # Generate 15 occurrences (more than max of 10)
        for i in range(15):
            result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        # Should be capped at 1.0
        self.assertEqual(rule['confidence'], 1.0)

    def test_recommendation_generation(self):
        """Test that recommendations are actionable"""
        tags = ['crawler-component', 'performance-issue', 'implementation-phase']

        # Generate 2 occurrences
        self.engine.analyze_multi_tag_patterns(tags)
        result = self.engine.analyze_multi_tag_patterns(tags)

        rule = result['prevention_rule']
        self.assertIn('recommendation', rule)
        # Should suggest profiling crawler operations
        self.assertTrue(len(rule['recommendation']) > 0)


class TestPreventionRuleQuerying(unittest.TestCase):
    """Test prevention rule query functionality"""

    def setUp(self):
        """Create temporary database with sample rules"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

        # Create some test rules by analyzing tag combinations
        test_combinations = [
            ['validation-error', 'api-component'],
            ['memory-problem', 'crawler-component'],
            ['performance-issue', 'storage-component']
        ]

        for tags in test_combinations:
            # Trigger rule generation (2 occurrences needed)
            self.engine.analyze_multi_tag_patterns(tags)
            self.engine.analyze_multi_tag_patterns(tags)

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_query_all_rules(self):
        """Test querying all prevention rules"""
        rules = self.engine.query_prevention_rules(min_confidence=0.0)
        # Should have 3 rules from setUp
        self.assertEqual(len(rules), 3)

    def test_query_specific_tags(self):
        """Test querying rules for specific tag combination"""
        rules = self.engine.query_prevention_rules(
            tags=['validation-error', 'api-component'],
            min_confidence=0.0
        )
        # Should find exactly 1 matching rule
        self.assertEqual(len(rules), 1)
        self.assertIn('api-component', rules[0]['tag_combination'])
        self.assertIn('validation-error', rules[0]['tag_combination'])

    def test_query_with_confidence_filter(self):
        """Test filtering rules by minimum confidence"""
        # High confidence threshold should return fewer rules
        high_conf_rules = self.engine.query_prevention_rules(min_confidence=0.9)
        all_rules = self.engine.query_prevention_rules(min_confidence=0.0)

        self.assertLessEqual(len(high_conf_rules), len(all_rules))

    def test_query_nonexistent_combination(self):
        """Test querying for non-existent tag combination"""
        rules = self.engine.query_prevention_rules(
            tags=['nonexistent-tag', 'another-fake-tag']
        )
        # Should return empty list
        self.assertEqual(len(rules), 0)


class TestStatistics(unittest.TestCase):
    """Test statistics gathering"""

    def setUp(self):
        """Create temporary database with sample data"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

        # Create sample data
        self.engine.analyze_multi_tag_patterns(['validation-error', 'api'])
        self.engine.analyze_multi_tag_patterns(['memory', 'crawler'])
        self.engine.analyze_multi_tag_patterns(['memory', 'crawler'])  # Trigger rule

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_get_statistics(self):
        """Test statistics gathering"""
        stats = self.engine.get_statistics()

        self.assertIn('total_combinations', stats)
        self.assertIn('total_rules', stats)
        self.assertIn('top_combinations', stats)

        # Should have 2 combinations
        self.assertEqual(stats['total_combinations'], 2)

        # Should have 1 rule (memory+crawler hit 2x)
        self.assertEqual(stats['total_rules'], 1)

    def test_top_combinations(self):
        """Test top combinations reporting"""
        stats = self.engine.get_statistics()
        top_combos = stats['top_combinations']

        # Should have entries
        self.assertGreater(len(top_combos), 0)

        # Each entry should have tags and count
        for combo in top_combos:
            self.assertIn('tags', combo)
            self.assertIn('count', combo)


class TestDatabaseIntegrity(unittest.TestCase):
    """Test database schema and integrity"""

    def setUp(self):
        """Create temporary database"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        self.engine = TagIntelligenceEngine(Path(self.temp_db.name))

    def tearDown(self):
        """Clean up temporary database"""
        self.engine.close()
        Path(self.temp_db.name).unlink()

    def test_tables_exist(self):
        """Test that required tables are created"""
        db = sqlite3.connect(self.temp_db.name)
        cursor = db.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
        tables = [row[0] for row in cursor]

        self.assertIn('tag_combinations', tables)
        self.assertIn('prevention_rules', tables)

        db.close()

    def test_indexes_exist(self):
        """Test that required indexes are created"""
        db = sqlite3.connect(self.temp_db.name)
        cursor = db.execute(
            "SELECT name FROM sqlite_master WHERE type='index'"
        )
        indexes = [row[0] for row in cursor]

        self.assertIn('idx_tag_tuple', indexes)
        self.assertIn('idx_rule_combination', indexes)

        db.close()


def run_tests():
    """Run all tests and report results"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestTagNormalization))
    suite.addTests(loader.loadTestsFromTestCase(TestTagCombinationTracking))
    suite.addTests(loader.loadTestsFromTestCase(TestPreventionRuleGeneration))
    suite.addTests(loader.loadTestsFromTestCase(TestPreventionRuleQuerying))
    suite.addTests(loader.loadTestsFromTestCase(TestStatistics))
    suite.addTests(loader.loadTestsFromTestCase(TestDatabaseIntegrity))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(run_tests())
