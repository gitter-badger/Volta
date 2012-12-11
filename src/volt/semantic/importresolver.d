// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.importresolver;

import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.context;
import volt.semantic.languagepass;

class ImportResolver : ScopeManager, Pass
{
public:
	ContextBuilder context;
	LanguagePass languagepass;
	ir.Module thisModule;

public:
	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Import i)
	{
		foreach (name; i.names) {
			auto mod = languagepass.getModule(name);
			context.transform(mod);
			if (mod is null) {
				throw new CompilerError(name.location, format("cannot find module '%s'.", name));
			}

			if (i.bind !is null && i.aliases.length == 0) { // import a = b;
				current.addScope(i, mod.myScope, i.bind.value);
			} else if (i.aliases.length == 0 && i.bind is null) {
				thisModule.importedModules ~= mod;
				thisModule.importedAccess ~= i.access;
			} else if (i.aliases.length > 0) {  // import a : b, c OR import a = b : c, d;
				ir.Scope bindScope;
				if (i.bind !is null) {
					auto newMod = new ir.Module();
					newMod.location = i.bind.location;
					newMod.name = new ir.QualifiedName();
					newMod.name.identifiers ~= i.bind;
					bindScope = new ir.Scope(newMod, "");
					newMod.myScope = bindScope;
				}
				foreach (ii, _alias; i.aliases) {
					string symbolFromImportName, symbolInModuleName;
					if (_alias[1] is null) {
						symbolFromImportName = symbolInModuleName = _alias[0].value;
					} else {
						symbolFromImportName = _alias[1].value;
						symbolInModuleName = _alias[0].value;
					}
					auto store = mod.myScope.getStore(symbolFromImportName);
					if (store is null) {
						throw new CompilerError(format("module '%s' has no symbol '%s'.", mod.name, symbolFromImportName));
					}
					if (i.bind !is null) {
						bindScope.addStore(store, symbolInModuleName);
					} else {
						thisModule.myScope.addStore(store, symbolInModuleName);
					}
				}
				if (i.bind !is null) current.addScope(i, bindScope, i.bind.value);
			}
		}
		return Continue;
	}

public:
	this(LanguagePass pass, ContextBuilder context)
	{
		assert(context !is null);
		languagepass = pass;
		this.context = context;
	}
}
