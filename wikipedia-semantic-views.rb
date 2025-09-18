#!/usr/bin/env python3
"""
RDF Triple Store for Semantic Wikipedia Pageviews

Models pageview data and semantic relationships as RDF triples,
enabling SPARQL queries and true knowledge graph operations.
"""

import gzip
import json
import re
import requests
import sqlite3
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Union
import time
from urllib.parse import quote
from dataclasses import dataclass


class NamespaceManager:
    """Manages RDF namespaces for the semantic pageview system."""
    
    def __init__(self):
        self.namespaces = {
            'pv': 'http://pageviews.semantic.org/',           # Our pageview ontology
            'wiki': 'http://en.wikipedia.org/wiki/',          # Wikipedia articles  
            'wd': 'http://www.wikidata.org/entity/',          # Wikidata entities
            'wdt': 'http://www.wikidata.org/prop/direct/',    # Wikidata direct properties
            'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
            'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
            'xsd': 'http://www.w3.org/2001/XMLSchema#',
            'foaf': 'http://xmlns.com/foaf/0.1/',             # Friend of a Friend
            'dbo': 'http://dbpedia.org/ontology/',            # DBpedia ontology
            'dbr': 'http://dbpedia.org/resource/',            # DBpedia resources
            'time': 'http://www.w3.org/2006/time#',           # Time ontology
            'geo': 'http://www.w3.org/2003/01/geo/wgs84_pos#' # Geo ontology
        }
    
    def uri(self, prefix: str, local: str) -> str:
        """Create a full URI from prefix and local name."""
        if prefix in self.namespaces:
            return f"{self.namespaces[prefix]}{quote(local, safe='')}"
        return local
    
    def expand(self, qname: str) -> str:
        """Expand a qualified name (prefix:local) to full URI."""
        if ':' in qname:
            prefix, local = qname.split(':', 1)
            return self.uri(prefix, local)
        return qname
    
    def compact(self, uri: str) -> str:
        """Try to compact a URI to prefix:local format."""
        for prefix, namespace in self.namespaces.items():
            if uri.startswith(namespace):
                local = uri[len(namespace):]
                return f"{prefix}:{local}"
        return uri


@dataclass
class Triple:
    """Represents an RDF triple (subject, predicate, object)."""
    subject: str
    predicate: str  
    object: str
    object_type: str = 'uri'  # 'uri', 'literal', 'typed_literal'
    datatype: Optional[str] = None
    language: Optional[str] = None
    
    def __str__(self):
        if self.object_type == 'literal':
            obj = f'"{self.object}"'
            if self.language:
                obj += f"@{self.language}"
            elif self.datatype:
                obj += f"^^<{self.datatype}>"
        else:
            obj = f"<{self.object}>"
        
        return f"<{self.subject}> <{self.predicate}> {obj} ."
    
    def to_dict(self):
        """Convert to dictionary for JSON serialization."""
        return {
            's': self.subject,
            'p': self.predicate,
            'o': self.object,
            'o_type': self.object_type,
            'datatype': self.datatype,
            'language': self.language
        }
    
    @classmethod
    def from_dict(cls, data):
        """Create Triple from dictionary."""
        return cls(
            subject=data['s'],
            predicate=data['p'],
            object=data['o'],
            object_type=data.get('o_type', 'uri'),
            datatype=data.get('datatype'),
            language=data.get('language')
        )


class TripleStore:
    """In-memory triple store with SPARQL-like query capabilities."""
    
    def __init__(self, store_file: Optional[str] = None):
        self.triples = []
        self.indexes = {
            'spo': defaultdict(lambda: defaultdict(set)),  # subject -> predicate -> [objects]
            'pos': defaultdict(lambda: defaultdict(set)),  # predicate -> object -> [subjects]  
            'osp': defaultdict(lambda: defaultdict(set))   # object -> subject -> [predicates]
        }
        self.store_file = store_file
        self.ns = NamespaceManager()
        
        if store_file and Path(store_file).exists():
            self.load_from_file()
    
    def add_triple(self, triple: Triple):
        """Add a triple to the store and update indexes."""
        # Avoid duplicates
        if any(t.subject == triple.subject and 
               t.predicate == triple.predicate and 
               t.object == triple.object for t in self.triples):
            return
        
        self.triples.append(triple)
        
        # Update indexes
        self.indexes['spo'][triple.subject][triple.predicate].add(triple.object)
        self.indexes['pos'][triple.predicate][triple.object].add(triple.subject)
        self.indexes['osp'][triple.object][triple.subject].add(triple.predicate)
    
    def add(self, subject: str, predicate: str, obj: Union[str, int, float, bool], 
            obj_type: str = 'uri', datatype: Optional[str] = None, 
            language: Optional[str] = None):
        """Convenience method to add a triple."""
        # Auto-detect literal types
        if obj_type == 'uri' and not str(obj).startswith('http'):
            if isinstance(obj, (int, float, bool)):
                obj_type = 'typed_literal'
                if isinstance(obj, int):
                    datatype = self.ns.uri('xsd', 'integer')
                elif isinstance(obj, float):
                    datatype = self.ns.uri('xsd', 'double')
                elif isinstance(obj, bool):
                    datatype = self.ns.uri('xsd', 'boolean')
                    obj = str(obj).lower()
            elif isinstance(obj, str):
                obj_type = 'literal'
        
        triple = Triple(
            subject=subject,
            predicate=predicate, 
            object=str(obj),
            object_type=obj_type,
            datatype=datatype,
            language=language
        )
        self.add_triple(triple)
    
    def query_spo(self, subject: Optional[str] = None, 
                  predicate: Optional[str] = None, 
                  obj: Optional[str] = None) -> List[Triple]:
        """Query triples by subject, predicate, object pattern."""
        results = []
        
        for triple in self.triples:
            if (subject is None or triple.subject == subject) and \
               (predicate is None or triple.predicate == predicate) and \
               (obj is None or triple.object == obj):
                results.append(triple)
        
        return results
    
    def get_subjects_with_predicate(self, predicate: str, obj: str) -> List[str]:
        """Get all subjects that have the given predicate-object pair."""
        return list(self.indexes['pos'][predicate][obj])
    
    def get_objects_with_predicate(self, subject: str, predicate: str) -> List[str]:
        """Get all objects for a subject-predicate pair."""
        return list(self.indexes['spo'][subject][predicate])
    
    def get_predicates(self, subject: str, obj: str) -> List[str]:
        """Get all predicates connecting subject and object."""
        return list(self.indexes['osp'][obj][subject])
    
    def sparql_select(self, variables: List[str], where_patterns: List[Tuple[str, str, str]], 
                     limit: Optional[int] = None) -> List[Dict[str, str]]:
        """Simple SPARQL SELECT implementation."""
        results = []
        
        # For simplicity, this handles basic triple patterns
        # In a full implementation, you'd have a proper SPARQL parser
        
        def match_pattern(pattern, triple):
            s_pattern, p_pattern, o_pattern = pattern
            
            matches = {}
            
            # Check subject match
            if s_pattern.startswith('?'):
                matches[s_pattern[1:]] = triple.subject
            elif s_pattern != triple.subject:
                return None
            
            # Check predicate match  
            if p_pattern.startswith('?'):
                matches[p_pattern[1:]] = triple.predicate
            elif p_pattern != triple.predicate:
                return None
            
            # Check object match
            if o_pattern.startswith('?'):
                matches[o_pattern[1:]] = triple.object
            elif o_pattern != triple.object:
                return None
                
            return matches
        
        # Simple implementation: find triples matching each pattern
        for triple in self.triples:
            for pattern in where_patterns:
                matches = match_pattern(pattern, triple)
                if matches:
                    # Filter to requested variables
                    result = {var: matches.get(var) for var in variables if var in matches}
                    if result and result not in results:
                        results.append(result)
        
        if limit:
            results = results[:limit]
            
        return results
    
    def save_to_file(self):
        """Save triple store to file."""
        if not self.store_file:
            return
        
        data = {
            'triples': [t.to_dict() for t in self.triples],
            'namespaces': self.ns.namespaces
        }
        
        with open(self.store_file, 'w') as f:
            json.dump(data, f, indent=2)
    
    def load_from_file(self):
        """Load triple store from file."""
        if not self.store_file or not Path(self.store_file).exists():
            return
        
        with open(self.store_file, 'r') as f:
            data = json.load(f)
        
        # Load namespaces
        if 'namespaces' in data:
            self.ns.namespaces.update(data['namespaces'])
        
        # Load triples
        for triple_data in data.get('triples', []):
            triple = Triple.from_dict(triple_data)
            self.add_triple(triple)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about the triple store."""
        return {
            'total_triples': len(self.triples),
            'unique_subjects': len(set(t.subject for t in self.triples)),
            'unique_predicates': len(set(t.predicate for t in self.triples)),
            'unique_objects': len(set(t.object for t in self.triples))
        }


class SemanticPageviewTripleStore:
    """Main class for converting pageview data to RDF triples."""
    
    def __init__(self, store_file: str = "./semantic_pageviews.json"):
        self.store = TripleStore(store_file)
        self.ns = self.store.ns
        
        # Initialize our ontology
        self._init_ontology()
        
        # Wikidata enricher (simplified for this example)
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'SemanticTripleStore/1.0'
        })
    
    def _init_ontology(self):
        """Initialize our pageview ontology."""
        # Define our classes
        self.store.add(
            self.ns.uri('pv', 'PageviewEvent'),
            self.ns.uri('rdf', 'type'),
            self.ns.uri('rdfs', 'Class')
        )
        
        self.store.add(
            self.ns.uri('pv', 'WikipediaArticle'), 
            self.ns.uri('rdf', 'type'),
            self.ns.uri('rdfs', 'Class')
        )
        
        # Define our properties
        properties = [
            ('hasPageviews', 'Number of pageviews'),
            ('hasTimestamp', 'Timestamp of measurement'), 
            ('hasProject', 'Wikipedia project (en.wikipedia, etc.)'),
            ('hasTrendingScore', 'Trending score vs baseline'),
            ('hasBaselineViews', 'Baseline pageview count'),
            ('isSpike', 'Whether this represents a traffic spike'),
            ('relatedToEvent', 'Related to external event'),
            ('hasCategory', 'Wikipedia category'),
            ('sameAs', 'Same entity as (Wikidata, DBpedia)')
        ]
        
        for prop, description in properties:
            prop_uri = self.ns.uri('pv', prop)
            self.store.add(prop_uri, self.ns.uri('rdf', 'type'), self.ns.uri('rdf', 'Property'))
            self.store.add(prop_uri, self.ns.uri('rdfs', 'comment'), description, 'literal')
    
    def process_pageview_record(self, title: str, views: int, timestamp: datetime, 
                              project: str, wikidata_id: Optional[str] = None,
                              categories: List[str] = None, trending_score: float = 0.0,
                              baseline_views: int = 0, is_spike: bool = False):
        """Convert a pageview record into RDF triples."""
        
        # Create unique URIs
        article_uri = self.ns.uri('wiki', title.replace(' ', '_'))
        timestamp_str = timestamp.isoformat()
        event_uri = self.ns.uri('pv', f"event_{title.replace(' ', '_')}_{timestamp_str}")
        
        # Article triples
        self.store.add(article_uri, self.ns.uri('rdf', 'type'), self.ns.uri('pv', 'WikipediaArticle'))
        self.store.add(article_uri, self.ns.uri('rdfs', 'label'), title, 'literal')
        self.store.add(article_uri, self.ns.uri('pv', 'hasProject'), project, 'literal')
        
        # Pageview event triples
        self.store.add(event_uri, self.ns.uri('rdf', 'type'), self.ns.uri('pv', 'PageviewEvent'))
        self.store.add(event_uri, self.ns.uri('pv', 'hasPageviews'), views, 'typed_literal')
        self.store.add(event_uri, self.ns.uri('pv', 'hasTimestamp'), timestamp_str, 
                      'typed_literal', self.ns.uri('xsd', 'dateTime'))
        self.store.add(event_uri, self.ns.uri('pv', 'hasTrendingScore'), trending_score, 'typed_literal')
        self.store.add(event_uri, self.ns.uri('pv', 'hasBaselineViews'), baseline_views, 'typed_literal')
        self.store.add(event_uri, self.ns.uri('pv', 'isSpike'), is_spike, 'typed_literal')
        
        # Link event to article
        self.store.add(event_uri, self.ns.uri('pv', 'about'), article_uri)
        
        # Wikidata linking
        if wikidata_id:
            wikidata_uri = self.ns.uri('wd', wikidata_id)
            self.store.add(article_uri, self.ns.uri('pv', 'sameAs'), wikidata_uri)
            self.store.add(wikidata_uri, self.ns.uri('rdf', 'type'), self.ns.uri('pv', 'WikidataEntity'))
        
        # Categories
        if categories:
            for category in categories[:5]:  # Limit categories
                category_uri = self.ns.uri('pv', f"category_{category.replace(' ', '_')}")
                self.store.add(category_uri, self.ns.uri('rdf', 'type'), self.ns.uri('pv', 'Category'))
                self.store.add(category_uri, self.ns.uri('rdfs', 'label'), category, 'literal')
                self.store.add(article_uri, self.ns.uri('pv', 'hasCategory'), category_uri)
    
    def enrich_with_wikidata(self, article_uri: str, wikidata_id: str):
        """Enrich article with Wikidata triples."""
        try:
            url = "https://www.wikidata.org/w/api.php"
            params = {
                'action': 'wbgetentities',
                'format': 'json', 
                'ids': wikidata_id,
                'props': 'claims|labels|descriptions'
            }
            
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            entity = data.get('entities', {}).get(wikidata_id, {})
            claims = entity.get('claims', {})
            
            wikidata_uri = self.ns.uri('wd', wikidata_id)
            
            # Add entity type (P31: instance of)
            if 'P31' in claims:
                for claim in claims['P31'][:3]:  # Limit to 3 types
                    if 'mainsnak' in claim:
                        type_id = claim['mainsnak'].get('datavalue', {}).get('value', {}).get('id')
                        if type_id:
                            type_uri = self.ns.uri('wd', type_id)
                            self.store.add(wikidata_uri, self.ns.uri('wdt', 'P31'), type_uri)
            
            # Add birth date (P569)
            if 'P569' in claims:
                birth_claim = claims['P569'][0]
                if 'mainsnak' in birth_claim:
                    birth_data = birth_claim['mainsnak'].get('datavalue', {}).get('value', {})
                    if 'time' in birth_data:
                        self.store.add(wikidata_uri, self.ns.uri('wdt', 'P569'), 
                                     birth_data['time'], 'typed_literal', 
                                     self.ns.uri('xsd', 'dateTime'))
            
            # Add coordinates (P625)
            if 'P625' in claims:
                coord_claim = claims['P625'][0]
                if 'mainsnak' in coord_claim:
                    coord_data = coord_claim['mainsnak'].get('datavalue', {}).get('value', {})
                    if 'latitude' in coord_data and 'longitude' in coord_data:
                        lat, lon = coord_data['latitude'], coord_data['longitude']
                        # Create a point geometry (simplified)
                        self.store.add(wikidata_uri, self.ns.uri('geo', 'lat'), 
                                     lat, 'typed_literal', self.ns.uri('xsd', 'double'))
                        self.store.add(wikidata_uri, self.ns.uri('geo', 'long'),
                                     lon, 'typed_literal', self.ns.uri('xsd', 'double'))
            
            # Add English label
            labels = entity.get('labels', {})
            if 'en' in labels:
                self.store.add(wikidata_uri, self.ns.uri('rdfs', 'label'), 
                             labels['en']['value'], 'literal', language='en')
            
        except Exception as e:
            print(f"Error enriching {wikidata_id}: {e}")
    
    def query_trending_articles(self, min_score: float = 1.0, limit: int = 20) -> List[Dict]:
        """Query trending articles using SPARQL-like patterns."""
        # This would be a proper SPARQL query:
        # SELECT ?article ?label ?views ?score WHERE {
        #   ?event a pv:PageviewEvent .
        #   ?event pv:about ?article .
        #   ?event pv:hasPageviews ?views .
        #   ?event pv:hasTrendingScore ?score .
        #   ?article rdfs:label ?label .
        #   FILTER(?score >= 1.0)
        # } ORDER BY DESC(?score) LIMIT 20
        
        results = []
        trending_events = []
        
        # Find trending events
        for triple in self.store.triples:
            if (triple.predicate == self.ns.uri('pv', 'hasTrendingScore') and 
                triple.object_type == 'typed_literal'):
                try:
                    score = float(triple.object)
                    if score >= min_score:
                        trending_events.append((triple.subject, score))
                except ValueError:
                    continue
        
        # Sort by score
        trending_events.sort(key=lambda x: x[1], reverse=True)
        
        # Get details for each trending event
        for event_uri, score in trending_events[:limit]:
            # Find article this event is about
            about_objects = self.store.get_objects_with_predicate(event_uri, self.ns.uri('pv', 'about'))
            if not about_objects:
                continue
                
            article_uri = about_objects[0]
            
            # Get article label
            labels = self.store.get_objects_with_predicate(article_uri, self.ns.uri('rdfs', 'label'))
            label = labels[0] if labels else article_uri.split('/')[-1]
            
            # Get pageviews
            pageviews_objects = self.store.get_objects_with_predicate(event_uri, self.ns.uri('pv', 'hasPageviews'))
            pageviews = int(pageviews_objects[0]) if pageviews_objects else 0
            
            # Get categories
            category_objects = self.store.get_objects_with_predicate(article_uri, self.ns.uri('pv', 'hasCategory'))
            categories = []
            for cat_uri in category_objects:
                cat_labels = self.store.get_objects_with_predicate(cat_uri, self.ns.uri('rdfs', 'label'))
                if cat_labels:
                    categories.append(cat_labels[0])
            
            results.append({
                'article_uri': article_uri,
                'label': label,
                'pageviews': pageviews,
                'trending_score': score,
                'categories': categories
            })
        
        return results
    
    def query_related_entities(self, entity_uri: str) -> List[Dict]:
        """Find entities related through Wikidata properties."""
        results = []
        
        # Find Wikidata URI for this entity
        wikidata_uris = self.store.get_objects_with_predicate(entity_uri, self.ns.uri('pv', 'sameAs'))
        
        if not wikidata_uris:
            return results
        
        wikidata_uri = wikidata_uris[0]
        
        # Find all outgoing Wikidata properties
        related_triples = self.store.query_spo(subject=wikidata_uri)
        
        for triple in related_triples:
            if triple.predicate.startswith(self.ns.uri('wdt', '')):
                # This is a Wikidata property
                property_name = triple.predicate.split('/')[-1]
                
                # Try to find Wikipedia articles for the related entity
                related_articles = self.store.get_subjects_with_predicate(
                    self.ns.uri('pv', 'sameAs'), triple.object
                )
                
                for article_uri in related_articles:
                    labels = self.store.get_objects_with_predicate(article_uri, self.ns.uri('rdfs', 'label'))
                    if labels:
                        results.append({
                            'related_article': article_uri,
                            'label': labels[0],
                            'relationship': property_name
                        })
        
        return results
    
    def export_rdf_turtle(self, output_file: str):
        """Export the triple store as RDF Turtle format."""
        with open(output_file, 'w') as f:
            # Write namespace prefixes
            for prefix, namespace in self.ns.namespaces.items():
                f.write(f"@prefix {prefix}: <{namespace}> .\n")
            f.write("\n")
            
            # Write triples
            for triple in self.store.triples:
                # Convert to compact form
                subject = self.ns.compact(triple.subject)
                predicate = self.ns.compact(triple.predicate)
                
                if triple.object_type == 'literal':
                    obj = f'"{triple.object}"'
                    if triple.language:
                        obj += f"@{triple.language}"
                    elif triple.datatype:
                        obj += f"^^{self.ns.compact(triple.datatype)}"
                else:
                    obj = self.ns.compact(triple.object)
                
                f.write(f"{subject} {predicate} {obj} .\n")
    
    def save(self):
        """Save the triple store."""
        self.store.save_to_file()


def demo_semantic_triples():
    """Demonstrate the RDF triple store for pageviews."""
    
    # Create semantic triple store
    semantic_store = SemanticPageviewTripleStore("demo_pageviews.json")
    
    # Add some sample pageview data
    sample_data = [
        ("Albert_Einstein", 15000, datetime(2024, 1, 15, 14), "en.wikipedia", "Q937", 
         ["Physicists", "Nobel laureates"], 2.5, 6000, True),
        ("Marie_Curie", 8500, datetime(2024, 1, 15, 14), "en.wikipedia", "Q7186",
         ["Chemists", "Nobel laureates", "Women scientists"], 1.8, 4700, False),
        ("Python_(programming_language)", 12000, datetime(2024, 1, 15, 14), "en.wikipedia", "Q28865",
         ["Programming languages"], 0.8, 15000, False)
    ]
    
    for title, views, timestamp, project, wd_id, cats, trending, baseline, spike in sample_data:
        semantic_store.process_pageview_record(
            title, views, timestamp, project, wd_id, cats, trending, baseline, spike
        )
        
        # Enrich with Wikidata (in real usage, you'd do this selectively)
        if wd_id:
            article_uri = semantic_store.ns.uri('wiki', title)
            # semantic_store.enrich_with_wikidata(article_uri, wd_id)  # Uncomment for real usage
    
    print("=== Triple Store Statistics ===")
    stats = semantic_store.store.get_stats()
    for key, value in stats.items():
        print(f"{key}: {value}")
    
    print("\n=== Trending Articles ===")
    trending = semantic_store.query_trending_articles(min_score=1.0, limit=5)
    for article in trending:
        print(f"• {article['label']}: {article['pageviews']} views, "
              f"trending score: {article['trending_score']:.1f}")
        if article['categories']:
            print(f"  Categories: {', '.join(article['categories'])}")
    
    print("\n=== Sample SPARQL-style Query Results ===")
    # Query for Nobel laureates
    nobel_results = semantic_store.store.sparql_select(
        variables=['article', 'label'],
        where_patterns=[
            ('?article', semantic_store.ns.uri('pv', 'hasCategory'), '?category'),
            ('?category', semantic_store.ns.uri('rdfs', 'label'), 'Nobel laureates'),
            ('?article', semantic_store.ns.uri('rdfs', 'label'), '?label')
        ]
    )
    
    print("Nobel laureates in our data:")
    for result in nobel_results:
        print(f"  • {result.get('label', 'Unknown')}")
    
    # Save and export
    semantic_store.save()
    semantic_store.export_rdf_turtle("pageviews.ttl")
    print(f"\nExported RDF data to pageviews.ttl")


if __name__ == "__main__":
    demo_semantic_triples()
