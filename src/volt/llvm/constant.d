/*#D*/
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code for generating constant expresions.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.constant;

import watt.text.format : format;

import volt.errors;
import volt.ir.util;
import ir = volta.ir;

import volt.llvm.common;
import volt.llvm.interfaces;

static import volt.semantic.mangle;


void getConstantValue(State state, ir.Exp exp, Value result)
{
	result.isPointer = false;
	switch (exp.nodeType) with (ir.NodeType) {
	case Unary:
		auto asUnary = cast(ir.Unary)exp;
		assert(asUnary !is null);
		return handleConstUnary(state, asUnary, result);
	case Constant:
		auto cnst = cast(ir.Constant)exp;
		assert(cnst !is null);
		return handleConstant(state, cnst, result);
	case ExpReference:
		auto expRef = cast(ir.ExpReference)exp;
		assert(expRef !is null);
		return handleConstExpReference(state, expRef, result);
	case ArrayLiteral:
		auto al = cast(ir.ArrayLiteral)exp;
		assert(al !is null);
		return handleArrayLiteral(state, al, result);
	case StructLiteral:
		auto sl = cast(ir.StructLiteral)exp;
		assert(sl !is null);
		return handleStructLiteral(state, sl, result);
	case UnionLiteral:
		auto ul = cast(ir.UnionLiteral)exp;
		assert(ul !is null);
		return handleUnionLiteral(state, ul, result);
	case ClassLiteral:
		auto literal = cast(ir.ClassLiteral)exp;
		assert(literal !is null);
		return handleClassLiteral(state, literal, result);
	case BuiltinExp:
		auto bexp = cast(ir.BuiltinExp)exp;
		assert(bexp !is null);
		return handleBuiltinExp(state, bexp, result);
	default:
		auto str = format(
			"could not get constant from expression '%s'",
			ir.nodeToString(exp));
		throw panic(/*#ref*/exp.loc, str);
	}
}

private:
/*
 *
 * Handle functions.
 *
 */

void handleBuiltinExp(State state, ir.BuiltinExp bexp, Value result)
{
	if (bexp.kind != ir.BuiltinExp.Kind.BuildVtable) {
		throw panic(/*#ref*/bexp.loc, "can only constant get from BuildVtable builtin exps");
	}
	auto tinfosStaticArrayType = bexp._class.classinfoVariable.type.toStaticArrayTypeFast();
	auto vals = new LLVMValueRef[](bexp.functionSink.length + 2);

	auto ptrType = LLVMPointerType(LLVMInt8TypeInContext(state.context), 0);
	LLVMTypeRef intType;
	if (state.target.isP64) {
		intType = LLVMInt64TypeInContext(state.context);
	} else {
		intType = LLVMInt32TypeInContext(state.context);
	}
	Type type;

	vals[0] = LLVMConstInt(intType, cast(ulong)tinfosStaticArrayType.length, false);
	vals[0] = LLVMConstIntToPtr(vals[0], ptrType);
	vals[1] = state.getVariableValue(bexp._class.classinfoVariable, /*#out*/type);
	vals[1] = LLVMConstBitCast(vals[1], ptrType);
	for (size_t i = 2; i < vals.length; ++i) {
		auto method = bexp.functionSink.get(i - 2);
		if (method.isAbstract) {
			assert(bexp._class.isAbstract);
			vals[i] = LLVMConstNull(ptrType);
			continue;
		}
		vals[i] = state.getFunctionValue(method, /*#out*/type);
		vals[i] = LLVMConstBitCast(vals[i], ptrType);
	}

	result.value = LLVMConstArray(ptrType, vals.ptr, cast(uint)vals.length);
	result.type = state.fromIr(bexp._class.vtableVariable.type);
}

void handleConstUnary(State state, ir.Unary asUnary, Value result)
{
	switch (asUnary.op) with (ir.Unary.Op) {
	case Cast:
		return handleConstCast(state, asUnary, result);
	case AddrOf:
		return handleConstAddrOf(state, asUnary, result);
	case Plus, Minus:
		return handleConstPlusMinus(state, asUnary, result);
	default:
		throw panicUnhandled(asUnary, ir.nodeToString(asUnary));
	}
}

void handleConstAddrOf(State state, ir.Unary de, Value result)
{
	auto expRef = cast(ir.ExpReference)de.value;
	assert(expRef !is null);
	assert(expRef.decl.declKind == ir.Declaration.Kind.Variable);

	auto var = cast(ir.Variable)expRef.decl;
	Type type;

	auto v = state.getVariableValue(var, /*#out*/type);

	auto pt = new ir.PointerType();
	pt.base = type.irType;
	assert(pt.base !is null);
	pt.mangledName = volt.semantic.mangle.mangle(pt);

	result.value = v;
	result.type = state.fromIr(pt);
	result.isPointer = false;
}

void handleConstPlusMinus(State state, ir.Unary asUnary, Value result)
{
	getConstantValue(state, asUnary.value, result);

	auto primType = cast(PrimitiveType)result.type;
	assert(primType !is null);
	assert(!result.isPointer);

	if (asUnary.op == ir.Unary.Op.Minus) {
		result.value = LLVMConstNeg(result.value);
	}
}

void handleConstCast(State state, ir.Unary asUnary, Value result)
{
	void error(string t) {
		auto str = format("error unary constant expression '%s'", t);
		throw panic(/*#ref*/asUnary.loc, str);
	}

	getConstantValue(state, asUnary.value, result);

	auto newType = state.fromIr(asUnary.type);
	auto oldType = result.type;

	auto newPrim = cast(PrimitiveType)newType;
	auto oldPrim = cast(PrimitiveType)oldType;
	if (newPrim !is null && oldPrim !is null) {
		result.type = newType;
		if (newPrim.boolean && oldPrim.floating) {
			result.value = LLVMConstFCmp(
				LLVMRealPredicate.ONE,
				result.value,
				LLVMConstNull(oldType.llvmType));
		} else if (newPrim.floating) {
			if (oldPrim.floating) {
				result.value = LLVMConstFPCast(result.value, newPrim.llvmType);
			} else if (oldPrim.signed) {
				result.value = LLVMConstSIToFP(result.value, newType.llvmType);
			} else {
				result.value = LLVMConstUIToFP(result.value, newType.llvmType);
			}
		} else if (oldPrim.floating) {
			if (newPrim.signed) {
				result.value = LLVMConstFPToSI(result.value, newType.llvmType);
			} else {
				result.value = LLVMConstFPToUI(result.value, newType.llvmType);
			}
		} else {
			result.value = LLVMConstIntCast(result.value, newPrim.llvmType, oldPrim.signed);
		}
		return;
	}

	{
		auto newTypePtr = cast(PointerType)newType;
		auto oldTypePtr = cast(PointerType)oldType;
		auto newTypeFn = cast(FunctionType)newType;
		auto oldTypeFn = cast(FunctionType)oldType;

		if (oldPrim !is null && newTypePtr !is null) {
			result.type = newType;
			result.value = LLVMConstIntToPtr(result.value, newTypePtr.llvmType);
			return;
		}

		if ((newTypePtr !is null || newTypeFn !is null) &&
		    (oldTypePtr !is null || oldTypeFn !is null)) {
			result.type = newType;
			result.value = LLVMConstBitCast(result.value, newType.llvmType);
			return;
		}
	}

	throw makeError(/*#ref*/asUnary.loc, "not a handle cast type.");
}

void handleConstExpReference(State state, ir.ExpReference expRef, Value result)
{
	switch(expRef.decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto func = cast(ir.Function)expRef.decl;
		assert(func !is null);
		result.isPointer = false;
		result.value = state.getFunctionValue(func, /*#out*/result.type);
		break;
	case FunctionParam:
		auto fp = cast(ir.FunctionParam)expRef.decl;
		assert(fp !is null);

		Type type;
		auto v = state.getVariableValue(fp, /*#out*/type);

		result.value = v;
		result.isPointer = false;
		result.type = type;
		break;
	case Variable:
		auto var = cast(ir.Variable)expRef.decl;
		assert(var !is null);

		/*!
		 * Whats going on here? Since constants ultimatly is handled
		 * by the linker, by either being just binary data in some
		 * segment or references to symbols, but not a copy of a
		 * values somewhere (which can later be changed), we can
		 * not statically load from a variable.
		 *
		 * But since useBaseStorage causes Variables to become a reference
		 * implicitly we can allow them trough. We use this for typeid.
		 * This might seem backwards but it works out.
		 */
		if (!var.useBaseStorage) {
			throw panic(/*#ref*/expRef.loc, "variables needs '&' for constants");
		}

		Type type;
		auto v = state.getVariableValue(var, /*#out*/type);

		result.value = v;
		result.isPointer = false;
		result.type = type;
		break;
	case EnumDeclaration:
		auto edecl = cast(ir.EnumDeclaration)expRef.decl;
		result.value = state.getConstant(edecl.assign);
		result.isPointer = false;
		result.type = state.fromIr(edecl.type);
		break;
	default:
		throw panic(/*#ref*/expRef.loc, "invalid decl type");
	}
}
